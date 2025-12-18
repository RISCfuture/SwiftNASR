import ArgumentParser
import Foundation
import SwiftNASR

actor ProgressTracker {
  var progress: Progress
  var isStarted = false
  var currentRecordType: String?

  var fractionCompleted: Double { progress.fractionCompleted }

  var isFinished: Bool { isStarted && progress.isFinished }

  init() {
    self.progress = Progress(totalUnitCount: 100)
  }

  func addChild(_ child: Progress, withPendingUnitCount inUnitCount: Int64) {
    self.progress.addChild(child, withPendingUnitCount: inUnitCount)
    isStarted = true
  }

  func setCurrentRecordType(_ recordType: String?) {
    self.currentRecordType = recordType
  }
}

actor ErrorCollector {
  private var errors: [RecordError] = []

  var errorCount: Int {
    errors.count
  }

  func record(_ error: Swift.Error, recordType: String) {
    errors.append(RecordError(recordType: recordType, error: error))
  }

  func errorsByRecordType() -> [String: [RecordError]] {
    Dictionary(grouping: errors, by: \.recordType)
  }

  func printSummary(verbose: Bool, formatName: String) {
    guard !errors.isEmpty else {
      print("\n\(formatName) - No parsing errors")
      return
    }

    if verbose {
      print("\n=== All Errors (\(formatName)) ===")
      for error in errors {
        print("[\(error.recordType)] \(error.error)")
      }
    } else {
      print("\n=== Error Summary (\(formatName)) ===")
      print("Total errors: \(errors.count)")

      let grouped = errorsByRecordType()
      let sortedTypes = grouped.keys.sorted { grouped[$0]!.count > grouped[$1]!.count }

      for recordType in sortedTypes {
        let typeErrors = grouped[recordType]!
        print("\n\(recordType) (\(typeErrors.count) error\(typeErrors.count == 1 ? "" : "s")):")
        let samplesToShow = min(3, typeErrors.count)
        for i in 0..<samplesToShow {
          print("  - \(typeErrors[i].error)")
        }
        if typeErrors.count > samplesToShow {
          print("  ... and \(typeErrors.count - samplesToShow) more")
        }
      }
    }
  }

  struct RecordError {
    let recordType: String
    let error: Swift.Error
  }
}

private let progressWeights: [RecordType: Int64] = [
  .airports: 44,
  .reportingPoints: 15,
  .terminalCommFacilities: 7,
  .preferredRoutes: 5,
  .locationIdentifiers: 3,
  .holds: 3,
  .militaryTrainingRoutes: 2,
  .airways: 2,
  .departureArrivalProceduresComplete: 2,
  .navaids: 1,
  .ILSes: 1,
  .codedDepartureRoutes: 1,
  .ARTCCFacilities: 1,
  .flightServiceStations: 1,
  .ATSAirways: 1,
  .ARTCCBoundarySegments: 1,
  .miscActivityAreas: 1,
  .parachuteJumpAreas: 1,
  .weatherReportingStations: 1,
  .FSSCommFacilities: 1,
  .weatherReportingLocations: 1
]
private let loadingWeight: Int64 = 5

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
    print("Loading \(formatName)…")
    let progress = self.progress
    try await nasr.load { child in
      Task { @MainActor in await progress.addChild(child, withPendingUnitCount: loadingWeight) }
    }
    print("Done loading \(formatName); parsing…")

    progressTask = trackProgress()
    let isCSV = formatName.lowercased() == "csv"
    let errorCollector = ErrorCollector()
    try await parseValues(nasr: nasr, isCSV: isCSV, errorCollector: errorCollector)

    // Clear the progress line before printing results
    print("\r" + String(repeating: " ", count: terminalWidth()) + "\r", terminator: "")

    // Print error summary
    await errorCollector.printSummary(verbose: verbose, formatName: formatName)

    print("\nSaving \(formatName)…")
    await saveData(nasr: nasr, formatName: formatName)

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
      let weight = progressWeights[recordType] ?? 1
      return { child in
        Task { @MainActor in
          await progress.setCurrentRecordType(String(describing: recordType))
          await progress.addChild(child, withPendingUnitCount: weight)
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

  private mutating func saveData(nasr: NASR, formatName: String) async {
    await print("\(formatName) - Airports: \(nasr.data.airports?.count ?? 0)")
    await print("\(formatName) - ARTCCs: \(nasr.data.ARTCCs?.count ?? 0)")
    await print("\(formatName) - FSSes: \(nasr.data.FSSes?.count ?? 0)")
    await print("\(formatName) - Navaids: \(nasr.data.navaids?.count ?? 0)")
    await print("\(formatName) - Fixes: \(nasr.data.fixes?.count ?? 0)")
    await print("\(formatName) - Weather Stations: \(nasr.data.weatherStations?.count ?? 0)")
    await print("\(formatName) - Airways: \(nasr.data.airways?.count ?? 0)")
    await print("\(formatName) - ILS Facilities: \(nasr.data.ILSFacilities?.count ?? 0)")
    await print(
      "\(formatName) - Terminal Comm Facilities: \(nasr.data.terminalCommFacilities?.count ?? 0)"
    )
    await print(
      "\(formatName) - Departure/Arrival Procedures Complete: \(nasr.data.departureArrivalProceduresComplete?.count ?? 0)"
    )
    await print("\(formatName) - Preferred Routes: \(nasr.data.preferredRoutes?.count ?? 0)")
    await print("\(formatName) - Holds: \(nasr.data.holds?.count ?? 0)")
    await print(
      "\(formatName) - Weather Reporting Locations: \(nasr.data.weatherReportingLocations?.count ?? 0)"
    )
    await print("\(formatName) - Parachute Jump Areas: \(nasr.data.parachuteJumpAreas?.count ?? 0)")
    await print(
      "\(formatName) - Military Training Routes: \(nasr.data.militaryTrainingRoutes?.count ?? 0)"
    )
    await print(
      "\(formatName) - Coded Departure Routes: \(nasr.data.codedDepartureRoutes?.count ?? 0)"
    )
    await print("\(formatName) - Misc Activity Areas: \(nasr.data.miscActivityAreas?.count ?? 0)")
    await print(
      "\(formatName) - ARTCC Boundary Segments: \(nasr.data.ARTCCBoundarySegments?.count ?? 0)"
    )
    await print("\(formatName) - FSS Comm Facilities: \(nasr.data.FSSCommFacilities?.count ?? 0)")
    await print("\(formatName) - ATS Airways: \(nasr.data.atsAirways?.count ?? 0)")
    await print(
      "\(formatName) - Location Identifiers: \(nasr.data.locationIdentifiers?.count ?? 0)"
    )

    do {
      // Ensure working directory exists
      try FileManager.default.createDirectory(
        at: workingDirectory,
        withIntermediateDirectories: true
      )

      let encoder = JSONZipEncoder()
      let data = try await encoder.encode(NASRDataCodable(data: nasr.data))

      let outPath = workingDirectory.appendingPathComponent(
        "distribution_\(formatName.lowercased()).json.zip"
      )
      try data.write(to: outPath)
      print("\(formatName) JSON file written to \(outPath)")
    } catch {
      print("Error saving \(formatName): \(error)")
    }
  }

  private func trackProgress() -> Task<Void, Swift.Error> {
    Task.detached {
      repeat {
        try await Task.sleep(for: .seconds(0.1))
        await renderProgressBar(progress: progress)
      } while await !progress.isFinished
    }
  }

  @MainActor
  private func renderProgressBar(progress: ProgressTracker, barWidth: Int = 80) async {
    let fractionCompleted = await progress.fractionCompleted
    let currentRecordType = await progress.currentRecordType
    let percent = Int((fractionCompleted * 100).rounded())

    // Build the status suffix (e.g., " - Parsing airports...")
    let statusSuffix: String
    if let recordType = currentRecordType {
      statusSuffix = " - Parsing \(recordType)..."
    } else {
      statusSuffix = ""
    }

    // Reserve space for percentage, brackets, and status
    let reservedSpace = 10 + statusSuffix.count
    let barWidth = max(terminalWidth() - reservedSpace, 10)  // Ensure minimum bar width

    // Ensure fractionCompleted is within valid bounds
    let clampedFraction = max(0.0, min(1.0, fractionCompleted))
    let completedWidth = Int(clampedFraction * Double(barWidth))

    // Ensure counts are non-negative
    let safeCompletedWidth = max(0, min(barWidth, completedWidth))
    let safeRemainingWidth = max(0, barWidth - safeCompletedWidth)

    let bar =
      String(repeating: "=", count: safeCompletedWidth)
      + String(repeating: " ", count: safeRemainingWidth)
    print("\r[\(bar)] \(percent)%\(statusSuffix)", terminator: "")
    fflush(stdout)  // Ensure that the output is flushed immediately
  }

  private func terminalWidth() -> Int {
    var w = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 {
      return Int(w.ws_col)
    }
    return 80
  }

  private func verifyCompletion(nasr: NASR, formatName: String, isCSV: Bool) async {
    var missingTypes: [String] = []

    // Check each record type for completion
    if await nasr.data.airports == nil { missingTypes.append("airports") }
    if await nasr.data.ARTCCs == nil { missingTypes.append("ARTCCs") }
    if await nasr.data.FSSes == nil { missingTypes.append("FSSes") }
    if await nasr.data.navaids == nil { missingTypes.append("navaids") }
    if await nasr.data.fixes == nil { missingTypes.append("fixes") }
    if await nasr.data.weatherStations == nil { missingTypes.append("weatherStations") }
    if await nasr.data.airways == nil { missingTypes.append("airways") }
    if await nasr.data.ILSFacilities == nil { missingTypes.append("ILSFacilities") }
    if await nasr.data.terminalCommFacilities == nil {
      missingTypes.append("terminalCommFacilities")
    }
    if await nasr.data.departureArrivalProceduresComplete == nil {
      missingTypes.append("departureArrivalProceduresComplete")
    }
    if await nasr.data.preferredRoutes == nil { missingTypes.append("preferredRoutes") }
    if await nasr.data.holds == nil { missingTypes.append("holds") }
    if await nasr.data.weatherReportingLocations == nil {
      missingTypes.append("weatherReportingLocations")
    }
    if await nasr.data.parachuteJumpAreas == nil { missingTypes.append("parachuteJumpAreas") }
    if await nasr.data.militaryTrainingRoutes == nil {
      missingTypes.append("militaryTrainingRoutes")
    }
    if isCSV {
      if await nasr.data.codedDepartureRoutes == nil {
        missingTypes.append("codedDepartureRoutes")
      }
    }
    if await nasr.data.miscActivityAreas == nil { missingTypes.append("miscActivityAreas") }
    if await nasr.data.ARTCCBoundarySegments == nil { missingTypes.append("ARTCCBoundarySegments") }
    if await nasr.data.FSSCommFacilities == nil { missingTypes.append("FSSCommFacilities") }
    if await nasr.data.atsAirways == nil { missingTypes.append("atsAirways") }
    if await nasr.data.locationIdentifiers == nil { missingTypes.append("locationIdentifiers") }

    if !missingTypes.isEmpty {
      print("\n=== \(formatName) Completion Warning ===")
      print("The following record types failed to parse entirely:")
      for missingType in missingTypes {
        print("  - \(missingType)")
      }
    }
  }

  // MARK: - Association Verification

  private func verifyAssociations(nasr: NASR, formatName: String, isCSV: Bool) async {
    var failures: [String] = []
    var successes: [String] = []

    // Helper to record results
    func check(_ description: String, _ condition: Bool) {
      if condition {
        successes.append(description)
      } else {
        failures.append(description)
      }
    }

    // Airport associations
    if let airports = await nasr.data.airports, !airports.isEmpty {
      // State associations (TXT only - no state parser for CSV)
      if !isCSV {
        // Find an airport with a state code to test state association
        if let airportWithState = airports.first(where: { $0.stateCode != nil }) {
          let state = await airportWithState.state
          check("Airport.state", state != nil)
        }

        // Find an airport with county state code
        if let airport = airports.first(where: { !$0.countyStateCode.isEmpty }) {
          let countyState = await airport.countyState
          check("Airport.countyState", countyState != nil)
        }
      }

      // boundaryARTCCs (TXT only - CSV doesn't have boundaryARTCCId)
      if !isCSV {
        if let airportWithARTCC = airports.first(where: { $0.boundaryARTCCId != nil }) {
          let artccs = await airportWithARTCC.boundaryARTCCs
          check("Airport.boundaryARTCCs", artccs != nil && !artccs!.isEmpty)
        }
      }

      // responsibleARTCCs
      if let airport = airports.first(where: { !$0.responsibleARTCCId.isEmpty }) {
        let artccs = await airport.responsibleARTCCs
        check("Airport.responsibleARTCCs", artccs != nil && !artccs!.isEmpty)
      }

      // tieInFSS
      if let airport = airports.first(where: { !$0.tieInFSSId.isEmpty }) {
        let fss = await airport.tieInFSS
        check("Airport.tieInFSS", fss != nil)
      }

      // alternateFSS (optional)
      if let airport = airports.first(where: { $0.alternateFSSId != nil }) {
        let fss = await airport.alternateFSS
        check("Airport.alternateFSS", fss != nil)
      }

      // NOTAMIssuer (optional)
      if let airport = airports.first(where: { $0.NOTAMIssuerId != nil }) {
        let fss = await airport.NOTAMIssuer
        check("Airport.NOTAMIssuer", fss != nil)
      }
    }

    // ARTCC associations
    if let artccs = await nasr.data.ARTCCs, !artccs.isEmpty {
      // State association (TXT only)
      if !isCSV {
        if let artccWithState = artccs.first(where: { $0.stateCode != nil }) {
          let state = await artccWithState.state
          check("ARTCC.state", state != nil)
        }
      }

      // CommFrequency.associatedAirport
      for artcc in artccs {
        if let freq = artcc.frequencies.first(where: { $0.associatedAirportCode != nil }) {
          let airport = await freq.associatedAirport
          check("ARTCC.CommFrequency.associatedAirport", airport != nil)
          break
        }
      }
    }

    // FSS associations
    if let fsses = await nasr.data.FSSes, !fsses.isEmpty {
      // nearestFSSWithTeletype
      if let fss = fsses.first(where: { $0.nearestFSSIdWithTeletype != nil }) {
        let nearestFSS = await fss.nearestFSSWithTeletype
        check("FSS.nearestFSSWithTeletype", nearestFSS != nil)
      }

      // State associations (TXT only)
      if !isCSV {
        // state
        if let fss = fsses.first(where: { $0.stateName != nil }) {
          let state = await fss.state
          check("FSS.state", state != nil)
        }

        // CommFacility.state
        for fss in fsses {
          if let facility = fss.commFacilities.first(where: { $0.stateName != nil }) {
            let state = await facility.state
            check("FSS.CommFacility.state", state != nil)
            break
          }
        }
      }

      // airport
      if let fss = fsses.first(where: { $0.airportId != nil }) {
        let airport = await fss.airport
        check("FSS.airport", airport != nil)
      }
    }

    // Navaid associations
    if let navaids = await nasr.data.navaids, !navaids.isEmpty {
      // state (TXT only)
      if !isCSV {
        if let navaid = navaids.first(where: { $0.stateName != nil }) {
          let state = await navaid.state
          check("Navaid.state", state != nil)
        }
      }

      // highAltitudeARTCC - test first 100 navaids to find one with an association
      var foundHighAltitudeARTCC = false
      for navaid in navaids.prefix(100) where !foundHighAltitudeARTCC {
        foundHighAltitudeARTCC = await navaid.highAltitudeARTCC != nil
      }
      check("Navaid.highAltitudeARTCC", foundHighAltitudeARTCC)

      // lowAltitudeARTCC
      var foundLowAltitudeARTCC = false
      for navaid in navaids.prefix(100) where !foundLowAltitudeARTCC {
        foundLowAltitudeARTCC = await navaid.lowAltitudeARTCC != nil
      }
      check("Navaid.lowAltitudeARTCC", foundLowAltitudeARTCC)

      // controllingFSS
      var foundControllingFSS = false
      for navaid in navaids.prefix(100) where !foundControllingFSS {
        foundControllingFSS = await navaid.controllingFSS != nil
      }
      check("Navaid.controllingFSS", foundControllingFSS)

      // VORCheckpoint.state (TXT only)
      if !isCSV {
        for navaid in navaids {
          if let checkpoint = navaid.checkpoints.first {
            let state = await checkpoint.state
            check("VORCheckpoint.state", state != nil)
            break
          }
        }
      }

      // VORCheckpoint.airport
      var foundCheckpointAirport = false
      for navaid in navaids where !foundCheckpointAirport {
        for checkpoint in navaid.checkpoints where !foundCheckpointAirport {
          foundCheckpointAirport = await checkpoint.airport != nil
        }
      }
      check("VORCheckpoint.airport", foundCheckpointAirport)
    }

    // Fix associations
    if let fixes = await nasr.data.fixes, !fixes.isEmpty {
      // highARTCC
      var foundHighARTCC = false
      for fix in fixes.prefix(100) where !foundHighARTCC {
        foundHighARTCC = await fix.highARTCC != nil
      }
      check("Fix.highARTCC", foundHighARTCC)

      // lowARTCC
      var foundLowARTCC = false
      for fix in fixes.prefix(100) where !foundLowARTCC {
        foundLowARTCC = await fix.lowARTCC != nil
      }
      check("Fix.lowARTCC", foundLowARTCC)
    }

    // WeatherStation associations
    if let stations = await nasr.data.weatherStations, !stations.isEmpty {
      if let station = stations.first(where: { $0.airportSiteNumber != nil }) {
        let airport = await station.airport
        check("WeatherStation.airport", airport != nil)
      }
    }

    // ILS associations
    if let ilsFacilities = await nasr.data.ILSFacilities, !ilsFacilities.isEmpty {
      if let ils = ilsFacilities.first {
        let airport = await ils.airport
        check("ILS.airport", airport != nil)
      }
    }

    // TerminalCommFacility associations
    if let facilities = await nasr.data.terminalCommFacilities, !facilities.isEmpty {
      if let facility = facilities.first(where: { $0.airportSiteNumber != nil }) {
        let airport = await facility.airport
        check("TerminalCommFacility.airport", airport != nil)
      }

      if let facility = facilities.first(where: { $0.tieInFSSId != nil }) {
        let fss = await facility.tieInFSS
        check("TerminalCommFacility.tieInFSS", fss != nil)
      }
    }

    // TXT-only associations
    if !isCSV {
      // ParachuteJumpArea associations
      if let pjas = await nasr.data.parachuteJumpAreas, !pjas.isEmpty {
        if let pja = pjas.first(where: { $0.airportSiteNumber != nil }) {
          let airport = await pja.airport
          check("ParachuteJumpArea.airport", airport != nil)
        }

        if let pja = pjas.first(where: { $0.navaidIdentifier != nil }) {
          let navaid = await pja.navaid
          check("ParachuteJumpArea.navaid", navaid != nil)
        }

        if let pja = pjas.first(where: { $0.FSSIdentifier != nil }) {
          let fss = await pja.fss
          check("ParachuteJumpArea.fss", fss != nil)
        }
      }

      // MilitaryTrainingRoute associations
      if let mtrs = await nasr.data.militaryTrainingRoutes, !mtrs.isEmpty {
        if let mtr = mtrs.first(where: { !$0.ARTCCIdentifiers.isEmpty }) {
          let artccs = await mtr.artccs
          check("MilitaryTrainingRoute.artccs", !artccs.isEmpty)
        }

        if let mtr = mtrs.first(where: { !$0.FSSIdentifiers.isEmpty }) {
          let fsses = await mtr.fsses
          check("MilitaryTrainingRoute.fsses", !fsses.isEmpty)
        }
      }

      // MiscActivityArea associations
      if let maas = await nasr.data.miscActivityAreas, !maas.isEmpty {
        if let maa = maas.first(where: { $0.navaidIdentifier != nil }) {
          let navaid = await maa.navaid
          check("MiscActivityArea.navaid", navaid != nil)
        }

        if let maa = maas.first(where: { $0.associatedAirportSiteNumber != nil }) {
          let airport = await maa.associatedAirport
          check("MiscActivityArea.associatedAirport", airport != nil)
        }
      }

      // ARTCCBoundarySegment associations
      if let segments = await nasr.data.ARTCCBoundarySegments, !segments.isEmpty {
        if let segment = segments.first {
          let artcc = await segment.artcc
          check("ARTCCBoundarySegment.artcc", artcc != nil)
        }
      }

      // FSSCommFacility associations
      if let facilities = await nasr.data.FSSCommFacilities, !facilities.isEmpty {
        if let facility = facilities.first(where: { $0.FSSIdentifier != nil }) {
          let fss = await facility.fss
          check("FSSCommFacility.fss", fss != nil)
        }

        if let facility = facilities.first(where: { $0.alternateFSSIdentifier != nil }) {
          let fss = await facility.alternateFSS
          check("FSSCommFacility.alternateFSS", fss != nil)
        }

        if let facility = facilities.first(where: { $0.navaidIdentifier != nil }) {
          let navaid = await facility.navaid
          check("FSSCommFacility.navaid", navaid != nil)
        }
      }

      // Hold associations
      if let holds = await nasr.data.holds, !holds.isEmpty {
        if let hold = holds.first(where: { $0.navaidIdentifier != nil }) {
          let navaid = await hold.navaid
          check("Hold.navaid", navaid != nil)
        }

        if let hold = holds.first(where: { $0.fixIdentifier != nil }) {
          let fix = await hold.fix
          check("Hold.fix", fix != nil)
        }

        if let hold = holds.first(where: { $0.fixARTCC != nil }) {
          let artcc = await hold.fixARTCCReference
          check("Hold.fixARTCCReference", artcc != nil)
        }

        if let hold = holds.first(where: { $0.fixStateCode != nil }) {
          let state = await hold.fixState
          check("Hold.fixState", state != nil)
        }
      }

      // PreferredRoute associations
      if let routes = await nasr.data.preferredRoutes, !routes.isEmpty {
        if let route = routes.first {
          let origin = await route.originLocation
          check("PreferredRoute.originLocation", origin != nil)

          let destination = await route.destinationLocation
          check("PreferredRoute.destinationLocation", destination != nil)
        }
      }

      // LocationIdentifier associations
      if let lids = await nasr.data.locationIdentifiers, !lids.isEmpty {
        if let lid = lids.first(where: { $0.controllingARTCC != nil }) {
          let artcc = await lid.artcc
          check("LocationIdentifier.artcc", artcc != nil)
        }

        if let lid = lids.first(where: { $0.landingFacilityFSS != nil }) {
          let fss = await lid.landingFacilityFSSReference
          check("LocationIdentifier.landingFacilityFSSReference", fss != nil)
        }
      }

      // WeatherReportingLocation associations
      if let locations = await nasr.data.weatherReportingLocations, !locations.isEmpty {
        if let location = locations.first(where: { $0.stateCode != nil }) {
          let state = await location.state
          check("WeatherReportingLocation.state", state != nil)
        }
      }

      // ATSAirway associations
      if let airways = await nasr.data.atsAirways, !airways.isEmpty {
        for airway in airways {
          if let routePoint = airway.routePoints.first(where: { $0.ARTCCIdentifier != nil }) {
            let artcc = await airway.artcc(for: routePoint)
            check("ATSAirway.artcc(for:)", artcc != nil)
            break
          }
        }

        for airway in airways {
          if let routePoint = airway.routePoints.first(where: { $0.navaidIdentifier != nil }) {
            let navaid = await airway.navaid(for: routePoint)
            check("ATSAirway.navaid(for:)", navaid != nil)
            break
          }
        }
      }

      // DepartureArrivalProcedure associations
      if let procedures = await nasr.data.departureArrivalProceduresComplete, !procedures.isEmpty {
        for procedure in procedures {
          if let adaptedAirport = procedure.adaptedAirports.first {
            let airport = await procedure.airport(for: adaptedAirport)
            check("DepartureArrivalProcedure.airport(for:)", airport != nil)
            break
          }
        }
      }
    }

    // CSV-only associations
    if isCSV {
      // CodedDepartureRoute associations
      if let cdrs = await nasr.data.codedDepartureRoutes, !cdrs.isEmpty {
        if let cdr = cdrs.first {
          let artcc = await cdr.artcc
          check("CodedDepartureRoute.artcc", artcc != nil)
        }
      }
    }

    // Print results
    print("\n=== Association Verification (\(formatName)) ===")
    print("Passed: \(successes.count)")
    if !failures.isEmpty {
      print("Failed: \(failures.count)")
      for failure in failures {
        print("  - \(failure)")
      }
    } else {
      print("All association tests passed!")
    }
  }

  private enum CodingKeys: String, CodingKey {
    case workingDirectory
    case format
    case localCSVPath
    case verbose
  }
}
