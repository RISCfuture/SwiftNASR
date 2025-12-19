import ArgumentParser
import Foundation
import SwiftNASR

@main
struct SwiftNASR_E2E: AsyncParsableCommand {
  @Option(
    name: .shortAndLong,
    help: "The working directory to store the distribution data.",
    transform: { .init(filePath: $0) }
  )
  var workingDirectory = URL.currentDirectory().appendingPathComponent(".SwiftNASR_TestData")

  @Option(
    name: .shortAndLong,
    help: "Data format to parse (txt or csv, or both if not specified)"
  )
  var format: String?

  @Option(
    name: .long,
    help: "Path to local CSV directory (for testing with local data)"
  )
  var localCSVPath: String?

  @Flag(name: .shortAndLong, help: "Print all errors instead of summary")
  var verbose: Bool = false

  @Option(
    name: .shortAndLong,
    help:
      "Comma-separated list of record types to parse (e.g., APT,NAV,FIX). If not specified, all record types are parsed."
  )
  var recordTypes: String?

  private var txtDistributionURL: URL {
    workingDirectory.appendingPathComponent("distribution_txt.zip")
  }
  private var csvDistributionURL: URL {
    workingDirectory.appendingPathComponent("distribution_csv.zip")
  }

  private let progress = ProgressTracker()
  private var progressTask: Task<Void, Swift.Error>?

  init() {}

  mutating func getTxtNASR() -> NASR? {
    // Ensure working directory exists
    try? FileManager.default.createDirectory(
      at: workingDirectory,
      withIntermediateDirectories: true
    )

    if FileManager.default.fileExists(atPath: txtDistributionURL.path) {
      return NASR.fromLocalArchive(txtDistributionURL)
    }
    print("Attempting to download TXT archive...")
    return NASR.fromInternetToFile(txtDistributionURL, format: .txt)
  }

  mutating func getCsvNASR() -> NASR? {
    // Ensure working directory exists
    try? FileManager.default.createDirectory(
      at: workingDirectory,
      withIntermediateDirectories: true
    )

    if let localCSVPath {
      let url = URL(filePath: localCSVPath)
      return NASR.fromLocalDirectory(url, format: .csv)
    }
    if FileManager.default.fileExists(atPath: csvDistributionURL.path) {
      return NASR.fromLocalArchive(csvDistributionURL, format: .csv)
    }
    print("Attempting to download CSV archive...")
    return NASR.fromInternetToFile(csvDistributionURL, format: .csv)
  }

  mutating func run() async throws {
    let formats = determineFormats()
    let selectedRecordTypes = try parseRecordTypesFilter()

    if let selected = selectedRecordTypes {
      print(
        "Filtering to record types: \(selected.map(\.rawValue).sorted().joined(separator: ", "))"
      )
    }

    if formats.contains("txt") {
      print("\n=== Testing TXT Format ===")
      if let nasr = getTxtNASR() {
        do {
          try await runForFormat(
            nasr: nasr,
            formatName: "TXT",
            selectedRecordTypes: selectedRecordTypes
          )
        } catch {
          print("Warning: TXT format test failed: \(error)")
          print("This may be due to the cycle data not being available for the current date.")
          print("Continuing with other formats...")
        }
      } else {
        print("Warning: Could not obtain TXT format NASR distribution")
        print("This may be due to the cycle data not being available for the current date.")
        print("Continuing with other formats...")
      }
    }

    if formats.contains("csv") {
      print("\n=== Testing CSV Format ===")
      if let nasr = getCsvNASR() {
        do {
          try await runForFormat(
            nasr: nasr,
            formatName: "CSV",
            selectedRecordTypes: selectedRecordTypes
          )
        } catch {
          print("Warning: CSV format test failed: \(error)")
          print("This may be due to the cycle data not being available for the current date.")
          print("Continuing...")
        }
      } else {
        print("Warning: Could not obtain CSV format NASR distribution")
        print("This may be due to the cycle data not being available for the current date.")
        print("Continuing...")
      }
    }
  }

  private func determineFormats() -> Set<String> {
    if let format = format?.lowercased() {
      if format == "both" {
        return ["txt", "csv"]
      }
      return [format]
    }
    return ["txt", "csv"]
  }

  private mutating func runForFormat(
    nasr: NASR,
    formatName: String,
    selectedRecordTypes: Set<RecordType>?
  ) async throws {
    let isCSV = formatName.lowercased() == "csv"
    let effectiveRecordTypes = effectiveTypes(for: isCSV, selectedRecordTypes: selectedRecordTypes)
    await progress.reset(
      totalUnitCount: totalWeight(isCSV: isCSV, selectedRecordTypes: effectiveRecordTypes)
    )
    print("Loading \(formatName)…")
    let progress = self.progress
    try await nasr.load { child in
      Task { @MainActor in await progress.addChild(child, withPendingUnitCount: loadingWeight) }
    }
    print("Done loading \(formatName); parsing…")

    progressTask = trackProgress(progress: progress)
    let errorCollector = ErrorCollector()
    try await parseValues(
      nasr: nasr,
      isCSV: isCSV,
      errorCollector: errorCollector,
      selectedRecordTypes: effectiveRecordTypes
    )

    // Clear the progress line before printing results
    print("\r" + String(repeating: " ", count: terminalWidth()) + "\r", terminator: "")

    // Print error summary
    await errorCollector.printSummary(verbose: verbose, formatName: formatName)

    print("\nSaving \(formatName)…")
    await saveData(
      nasr: nasr,
      formatName: formatName,
      workingDirectory: workingDirectory,
      selectedRecordTypes: effectiveRecordTypes
    )

    // Verify completion
    await verifyCompletion(
      nasr: nasr,
      formatName: formatName,
      isCSV: isCSV,
      selectedRecordTypes: effectiveRecordTypes
    )

    // Verify associations
    print("\nVerifying associations…")
    await verifyAssociations(
      nasr: nasr,
      formatName: formatName,
      isCSV: isCSV,
      selectedRecordTypes: effectiveRecordTypes
    )
  }

  /// Returns the effective set of record types to parse, filtering by format availability and user selection.
  private func effectiveTypes(for isCSV: Bool, selectedRecordTypes: Set<RecordType>?) -> Set<
    RecordType
  > {
    let availableTypes = isCSV ? CSVRecordTypes : txtRecordTypes
    if let selected = selectedRecordTypes {
      return availableTypes.intersection(selected)
    }
    return availableTypes
  }

  private mutating func parseValues(
    nasr: NASR,
    isCSV: Bool,
    errorCollector: ErrorCollector,
    selectedRecordTypes: Set<RecordType>
  ) async throws {
    let progress = self.progress

    // Helper to create progress handler for a record type
    func progressHandler(for recordType: RecordType) -> @Sendable (Progress) -> Void {
      let recordWeight = weight(for: recordType, isCSV: isCSV)
      return { child in
        Task { @MainActor in
          await progress.setCurrentRecordType(String(describing: recordType))
          await progress.addChild(child, withPendingUnitCount: recordWeight)
        }
      }
    }

    // Helper to create error handler for a record type
    func errorHandler(for recordType: RecordType) -> @Sendable (Swift.Error) -> Bool {
      let typeName = String(describing: recordType)
      return { error in
        Task { await errorCollector.record(error, recordType: typeName) }
        return true
      }
    }

    // States must be parsed first for state associations to work (TXT only)
    if !isCSV {
      try await nasr.parse(
        .states,
        errorHandler: errorHandler(for: .states)
      )
    }

    // Parse all selected record types concurrently
    try await withThrowingTaskGroup(of: Void.self) { group in
      for recordType in selectedRecordTypes {
        group.addTask {
          _ = try await nasr.parse(
            recordType,
            withProgress: progressHandler(for: recordType),
            errorHandler: errorHandler(for: recordType)
          )
        }
      }
      try await group.waitForAll()
    }

    // Clear current record type when done
    await progress.setCurrentRecordType(nil)
  }

  /// Parses the record types option into a set of RecordType values.
  /// Returns nil if no filter was specified (meaning all types should be parsed).
  private func parseRecordTypesFilter() throws -> Set<RecordType>? {
    guard let recordTypesString = recordTypes else { return nil }

    var selectedTypes = Set<RecordType>()
    let codes = recordTypesString.split(separator: ",").map {
      $0.trimmingCharacters(in: .whitespaces)
    }

    for code in codes {
      if let recordType = RecordType(rawValue: code) {
        selectedTypes.insert(recordType)
      } else {
        // Try case-insensitive match
        if let matchingType = allRecordTypes.first(where: {
          $0.rawValue.lowercased() == code.lowercased()
        }) {
          selectedTypes.insert(matchingType)
        } else {
          throw ValidationError(
            "Unknown record type: '\(code)'. Valid types are: \(allRecordTypes.map(\.rawValue).sorted().joined(separator: ", "))"
          )
        }
      }
    }

    if selectedTypes.isEmpty {
      throw ValidationError("At least one valid record type must be specified.")
    }

    return selectedTypes
  }

  private enum CodingKeys: String, CodingKey {
    case workingDirectory
    case format
    case localCSVPath
    case verbose
    case recordTypes
  }
}
