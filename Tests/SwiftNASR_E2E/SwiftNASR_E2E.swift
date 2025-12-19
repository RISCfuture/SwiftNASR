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

    if formats.contains("txt") {
      print("\n=== Testing TXT Format ===")
      if let nasr = getTxtNASR() {
        do {
          try await runForFormat(nasr: nasr, formatName: "TXT")
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
          try await runForFormat(nasr: nasr, formatName: "CSV")
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

  private mutating func runForFormat(nasr: NASR, formatName: String) async throws {
    let isCSV = formatName.lowercased() == "csv"
    await progress.reset(totalUnitCount: totalWeight(isCSV: isCSV))
    print("Loading \(formatName)…")
    let progress = self.progress
    try await nasr.load { child in
      Task { @MainActor in await progress.addChild(child, withPendingUnitCount: loadingWeight) }
    }
    print("Done loading \(formatName); parsing…")

    progressTask = trackProgress(progress: progress)
    let errorCollector = ErrorCollector()
    try await parseValues(nasr: nasr, isCSV: isCSV, errorCollector: errorCollector)

    // Clear the progress line before printing results
    print("\r" + String(repeating: " ", count: terminalWidth()) + "\r", terminator: "")

    // Print error summary
    await errorCollector.printSummary(verbose: verbose, formatName: formatName)

    print("\nSaving \(formatName)…")
    await saveData(nasr: nasr, formatName: formatName, workingDirectory: workingDirectory)

    // Verify completion
    await verifyCompletion(nasr: nasr, formatName: formatName, isCSV: isCSV)

    // Verify associations
    print("\nVerifying associations…")
    await verifyAssociations(nasr: nasr, formatName: formatName, isCSV: isCSV)
  }

  private mutating func parseValues(
    nasr: NASR,
    isCSV: Bool,
    errorCollector: ErrorCollector
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

    async let airports = try nasr.parse(
      .airports,
      withProgress: progressHandler(for: .airports),
      errorHandler: errorHandler(for: .airports)
    )

    async let artccs = try nasr.parse(
      .ARTCCFacilities,
      withProgress: progressHandler(for: .ARTCCFacilities),
      errorHandler: errorHandler(for: .ARTCCFacilities)
    )

    async let fsses = try nasr.parse(
      .flightServiceStations,
      withProgress: progressHandler(for: .flightServiceStations),
      errorHandler: errorHandler(for: .flightServiceStations)
    )

    async let navaids = try nasr.parse(
      .navaids,
      withProgress: progressHandler(for: .navaids),
      errorHandler: errorHandler(for: .navaids)
    )

    async let fixes = try nasr.parse(
      .reportingPoints,
      withProgress: progressHandler(for: .reportingPoints),
      errorHandler: errorHandler(for: .reportingPoints)
    )

    async let weatherStations = try nasr.parse(
      .weatherReportingStations,
      withProgress: progressHandler(for: .weatherReportingStations),
      errorHandler: errorHandler(for: .weatherReportingStations)
    )

    async let airways = try nasr.parse(
      .airways,
      withProgress: progressHandler(for: .airways),
      errorHandler: errorHandler(for: .airways)
    )

    async let ILSFacilities = try nasr.parse(
      .ILSes,
      withProgress: progressHandler(for: .ILSes),
      errorHandler: errorHandler(for: .ILSes)
    )

    async let terminalCommFacilities = try nasr.parse(
      .terminalCommFacilities,
      withProgress: progressHandler(for: .terminalCommFacilities),
      errorHandler: errorHandler(for: .terminalCommFacilities)
    )

    // The following record types are TXT-only (no CSV parser)
    async let departureArrivalProceduresComplete: Bool = {
      if !isCSV {
        return try await nasr.parse(
          .departureArrivalProceduresComplete,
          withProgress: progressHandler(for: .departureArrivalProceduresComplete),
          errorHandler: errorHandler(for: .departureArrivalProceduresComplete)
        )
      }
      return true
    }()

    async let preferredRoutes: Bool = {
      if !isCSV {
        return try await nasr.parse(
          .preferredRoutes,
          withProgress: progressHandler(for: .preferredRoutes),
          errorHandler: errorHandler(for: .preferredRoutes)
        )
      }
      return true
    }()

    async let holds: Bool = {
      if !isCSV {
        return try await nasr.parse(
          .holds,
          withProgress: progressHandler(for: .holds),
          errorHandler: errorHandler(for: .holds)
        )
      }
      return true
    }()

    async let weatherReportingLocations: Bool = {
      if !isCSV {
        return try await nasr.parse(
          .weatherReportingLocations,
          withProgress: progressHandler(for: .weatherReportingLocations),
          errorHandler: errorHandler(for: .weatherReportingLocations)
        )
      }
      return true
    }()

    async let parachuteJumpAreas: Bool = {
      if !isCSV {
        return try await nasr.parse(
          .parachuteJumpAreas,
          withProgress: progressHandler(for: .parachuteJumpAreas),
          errorHandler: errorHandler(for: .parachuteJumpAreas)
        )
      }
      return true
    }()

    async let militaryTrainingRoutes: Bool = {
      if !isCSV {
        return try await nasr.parse(
          .militaryTrainingRoutes,
          withProgress: progressHandler(for: .militaryTrainingRoutes),
          errorHandler: errorHandler(for: .militaryTrainingRoutes)
        )
      }
      return true
    }()

    // codedDepartureRoutes is only available in CSV format
    async let codedDepartureRoutes: Bool = {
      if isCSV {
        return try await nasr.parse(
          .codedDepartureRoutes,
          withProgress: progressHandler(for: .codedDepartureRoutes),
          errorHandler: errorHandler(for: .codedDepartureRoutes)
        )
      }
      return true
    }()

    async let miscActivityAreas: Bool = {
      if !isCSV {
        return try await nasr.parse(
          .miscActivityAreas,
          withProgress: progressHandler(for: .miscActivityAreas),
          errorHandler: errorHandler(for: .miscActivityAreas)
        )
      }
      return true
    }()

    async let ARTCCBoundarySegments: Bool = {
      if !isCSV {
        return try await nasr.parse(
          .ARTCCBoundarySegments,
          withProgress: progressHandler(for: .ARTCCBoundarySegments),
          errorHandler: errorHandler(for: .ARTCCBoundarySegments)
        )
      }
      return true
    }()

    async let FSSCommFacilities: Bool = {
      if !isCSV {
        return try await nasr.parse(
          .FSSCommFacilities,
          withProgress: progressHandler(for: .FSSCommFacilities),
          errorHandler: errorHandler(for: .FSSCommFacilities)
        )
      }
      return true
    }()

    async let atsAirways: Bool = {
      if !isCSV {
        return try await nasr.parse(
          .ATSAirways,
          withProgress: progressHandler(for: .ATSAirways),
          errorHandler: errorHandler(for: .ATSAirways)
        )
      }
      return true
    }()

    async let locationIdentifiers: Bool = {
      if !isCSV {
        return try await nasr.parse(
          .locationIdentifiers,
          withProgress: progressHandler(for: .locationIdentifiers),
          errorHandler: errorHandler(for: .locationIdentifiers)
        )
      }
      return true
    }()

    _ = try await [
      airports, artccs, fsses, navaids, fixes, weatherStations, airways, ILSFacilities,
      terminalCommFacilities, departureArrivalProceduresComplete,
      preferredRoutes, holds, weatherReportingLocations, parachuteJumpAreas,
      militaryTrainingRoutes, codedDepartureRoutes, miscActivityAreas, ARTCCBoundarySegments,
      FSSCommFacilities, atsAirways, locationIdentifiers
    ]

    // Clear current record type when done
    await progress.setCurrentRecordType(nil)
  }

  private enum CodingKeys: String, CodingKey {
    case workingDirectory
    case format
    case localCSVPath
    case verbose
  }
}
