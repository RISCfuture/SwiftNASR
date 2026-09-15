import ArgumentParser
import Foundation
import SwiftNASR

@main
struct SwiftNASR_E2E: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Downloads, parses, and verifies a full NASR distribution.",
    discussion: """
      Exits nonzero when a distribution could not be downloaded, a record type parsed to nothing, \
      a record was dropped, or an association check failed. Unrepresentable fields are reported \
      but do not fail the run.
      """
  )

  @Option(
    name: .shortAndLong,
    help: "The working directory to store the distribution data.",
    transform: { .init(filePath: $0) }
  )
  var workingDirectory = URL.currentDirectory().appendingPathComponent(".SwiftNASR_TestData")

  @Option(name: .shortAndLong, help: "Data format to parse.")
  var format = FormatSelection.both

  @Option(
    name: .long,
    help: "Cycle to parse: ‘effective’, ‘next’, or an effective date as YYYY-MM-DD.",
    transform: parseCycle
  )
  var cycle: Cycle?

  @Option(
    name: .long,
    help: "Path to local CSV directory (for testing with local data)"
  )
  var localCSVPath: String?

  @Option(name: .customLong("report"), help: "Path to write the JSON run report to.")
  var reportPath: String?

  @Option(
    name: .customLong("baseline"),
    help: "An earlier run's report, whose record counts this run is compared against."
  )
  var baselinePath: String?

  @Flag(
    name: .long,
    inversion: .prefixedNo,
    help: "Encode the parsed data to a zipped JSON file."
  )
  var save = true

  @Option(name: .long, help: "Percentage a record count must move by to count as drift.")
  var driftPercent = 10

  @Option(name: .long, help: "Records a count must move by to count as drift.")
  var driftMinimum = 25

  @Flag(name: .shortAndLong, help: "Print all errors instead of a sample")
  var verbose = false

  @Option(
    name: .shortAndLong,
    help:
      "Comma-separated list of record types to parse (e.g., APT,NAV,FIX). If not specified, all record types are parsed."
  )
  var recordTypes: String?

  /// The cycle this run targets.
  private var targetCycle: Cycle { cycle ?? .effective }

  init() {}

  func validate() throws {
    guard localCSVPath == nil || cycle == nil else {
      throw ValidationError("--cycle cannot be combined with --local-csv-path.")
    }
    guard driftPercent >= 0, driftMinimum >= 0 else {
      throw ValidationError("Drift thresholds cannot be negative.")
    }
  }

  func run() async throws {
    let selectedRecordTypes = try parseRecordTypesFilter()
    if let selected = selectedRecordTypes {
      print(
        "Filtering to record types: \(selected.map(\.rawValue).sorted().joined(separator: ", "))"
      )
    }

    let baseline = try comparableBaseline(filter: selectedRecordTypes)

    var formatReports: [FormatReport] = []
    var samples: [ErrorSample] = []
    for dataFormat in format.formats {
      let (formatReport, formatSamples) = await runForFormat(
        dataFormat,
        selectedRecordTypes: selectedRecordTypes,
        baseline: baseline?.formats[dataFormat.rawValue.lowercased()]
      )
      formatReports.append(formatReport)
      samples.append(contentsOf: formatSamples)
    }

    let report = RunReport(
      cycle: targetCycle,
      recordTypeFilter: selectedRecordTypes,
      formats: formatReports,
      errorSamples: samples,
      drift: baseline.map {
        driftFindings(
          from: $0,
          to: formatReports,
          percent: driftPercent,
          minimum: driftMinimum
        )
      } ?? []
    )

    report.printSummary()
    if let reportPath {
      try report.write(to: URL(filePath: reportPath))
    }
    if report.failed { throw ExitCode.failure }
  }

  /// An earlier run's report, if one was given and it covers the same record types. Counts and
  /// error tallies from a run narrowed by `--record-types` are not comparable with a full run's.
  private func comparableBaseline(filter: Set<RecordType>?) throws -> RunReport? {
    guard let baselinePath else { return nil }
    let baseline = try RunReport.read(from: URL(filePath: baselinePath))
    guard baseline.recordTypeFilter == filter.map({ $0.map(\.rawValue).sorted() }) else {
      print("Ignoring the baseline: it covers a different set of record types.")
      return nil
    }
    return baseline
  }

  private func runForFormat(
    _ dataFormat: DataFormat,
    selectedRecordTypes: Set<RecordType>?,
    baseline: FormatReport?
  ) async -> (FormatReport, [ErrorSample]) {
    let startedAt = Date()
    let source = makeSource(for: dataFormat)
    let parsedTypes = effectiveTypes(for: dataFormat, selectedRecordTypes: selectedRecordTypes)
    let errorCollector = ErrorCollector(sampleLimit: verbose ? .max : defaultErrorSampleLimit)

    func report(
      abortReason: String? = nil,
      saveError: String? = nil,
      distributionCycle: Cycle? = nil,
      recordTypes: [String: RecordTypeReport] = [:],
      associations: AssociationReport = .notRun
    ) -> FormatReport {
      .init(
        format: dataFormat,
        expectedCycle: source.expectedCycle,
        distributionCycle: distributionCycle,
        abortReason: abortReason,
        saveError: saveError,
        durationSeconds: Int(Date().timeIntervalSince(startedAt).rounded()),
        recordTypes: recordTypes,
        associations: associations,
        baseline: baseline
      )
    }

    print("\n=== Testing \(dataFormat.rawValue) Format ===")
    do {
      try await loadAndParse(
        source.nasr,
        format: dataFormat,
        recordTypes: parsedTypes,
        errorCollector: errorCollector
      )
    } catch {
      clearProgressLine()
      return (report(abortReason: error.localizedDescription), [])
    }
    clearProgressLine()

    var saveError: String?
    if save {
      print("\nSaving \(dataFormat.rawValue)…")
      do {
        try await saveData(
          nasr: source.nasr,
          format: dataFormat,
          workingDirectory: workingDirectory
        )
      } catch {
        saveError = error.localizedDescription
      }
    }

    print("\nVerifying associations…")
    let associations = await verifyAssociations(
      nasr: source.nasr,
      format: dataFormat,
      selectedRecordTypes: parsedTypes
    )

    let tallies = errorCollector.talliesByRecordType
    let reports = await recordTypeReports(
      of: source.nasr,
      recordTypes: reportedTypes(for: dataFormat, parsing: parsedTypes),
      tallies: tallies
    )

    return (
      report(
        saveError: saveError,
        distributionCycle: await source.nasr.data.cycle,
        recordTypes: reports,
        associations: associations
      ),
      errorSamples(format: dataFormat, tallies: tallies)
    )
  }

  /// A local archive already downloaded for this cycle is reused; anything else is downloaded.
  /// The cache is named after the FAA's own filename, so an archive from another cycle can never
  /// stand in for the one that was asked for.
  private func makeSource(for dataFormat: DataFormat) -> Source {
    if dataFormat == .csv, let localCSVPath {
      return .init(
        nasr: .fromLocalDirectory(URL(filePath: localCSVPath), format: .csv),
        expectedCycle: nil
      )
    }

    try? FileManager.default.createDirectory(
      at: workingDirectory,
      withIntermediateDirectories: true
    )

    let archive = cachedArchiveURL(for: dataFormat)
    if FileManager.default.fileExists(atPath: archive.path) {
      return .init(nasr: .fromLocalArchive(archive, format: dataFormat), expectedCycle: targetCycle)
    }

    print("Downloading the \(dataFormat.rawValue) archive for cycle \(targetCycle)…")
    let downloader = ArchiveFileDownloader(
      cycle: targetCycle,
      format: dataFormat,
      location: archive
    )
    return .init(nasr: .init(loader: downloader), expectedCycle: targetCycle)
  }

  private func cachedArchiveURL(for dataFormat: DataFormat) -> URL {
    let filename = ArchiveFileDownloader(cycle: targetCycle, format: dataFormat)
      .cycleURL.lastPathComponent
    return workingDirectory.appendingPathComponent(filename)
  }

  private func loadAndParse(
    _ nasr: NASR,
    format dataFormat: DataFormat,
    recordTypes: Set<RecordType>,
    errorCollector: ErrorCollector
  ) async throws {
    let progress = ProgressTracker(
      totalCount: totalWeight(format: dataFormat, selectedRecordTypes: recordTypes)
    )
    print("Loading \(dataFormat.rawValue)…")
    try await nasr.load(progress: progress.manager.subprogress(assigningCount: loadingWeight))
    print("Done loading \(dataFormat.rawValue); parsing…")

    let progressBar = trackProgress(progress: progress)
    defer { progressBar.cancel() }
    try await parseValues(
      nasr: nasr,
      format: dataFormat,
      errorCollector: errorCollector,
      selectedRecordTypes: recordTypes,
      progress: progress
    )
    progressBar.cancel()
    await progressBar.value
  }

  /// Returns the effective set of record types to parse, filtering by format availability and user selection.
  private func effectiveTypes(
    for dataFormat: DataFormat,
    selectedRecordTypes: Set<RecordType>?
  ) -> Set<RecordType> {
    let availableTypes = availableRecordTypes(for: dataFormat)
    if let selected = selectedRecordTypes {
      return availableTypes.intersection(selected)
    }
    return availableTypes
  }

  /// The record types a format reports on: those parsed, plus `states`, which every TXT run parses
  /// so that state associations resolve. It is deliberately absent from the progress weighting,
  /// which only covers the tracked task group.
  private func reportedTypes(
    for dataFormat: DataFormat,
    parsing parsedTypes: Set<RecordType>
  ) -> Set<RecordType> {
    dataFormat == .csv ? parsedTypes : parsedTypes.union([.states])
  }

  private func parseValues(
    nasr: NASR,
    format dataFormat: DataFormat,
    errorCollector: ErrorCollector,
    selectedRecordTypes: Set<RecordType>,
    progress: ProgressTracker
  ) async throws {
    // Helper to create error handler for a record type
    func errorHandler() -> @Sendable (RecordParseError) -> ParseDisposition {
      { error in
        errorCollector.record(error)
        return .proceed
      }
    }

    // States must be parsed first for state associations to work (TXT only)
    if dataFormat == .txt {
      try await nasr.parse(.states, errorHandler: errorHandler())
    }

    // Parse all selected record types concurrently
    try await withThrowingTaskGroup(of: Void.self) { group in
      for recordType in selectedRecordTypes {
        let recordWeight = weight(for: recordType, format: dataFormat)
        group.addTask {
          progress.setCurrentRecordType(String(describing: recordType))
          _ = try await nasr.parse(
            recordType,
            progress: progress.manager.subprogress(assigningCount: recordWeight),
            errorHandler: errorHandler()
          )
        }
      }
      try await group.waitForAll()
    }

    // Clear current record type when done
    progress.setCurrentRecordType(nil)
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

  /// A format's data source, and the cycle its archive is expected to declare. A local directory
  /// contains whatever cycle it contains, so there is nothing to hold it to.
  private struct Source {
    let nasr: NASR
    let expectedCycle: Cycle?
  }

  // periphery:ignore - used by ArgumentParser's Decodable-based command parsing
  private enum CodingKeys: String, CodingKey {
    case workingDirectory
    case format
    case cycle
    case localCSVPath
    case reportPath
    case baselinePath
    case save
    case driftPercent
    case driftMinimum
    case verbose
    case recordTypes
  }
}
