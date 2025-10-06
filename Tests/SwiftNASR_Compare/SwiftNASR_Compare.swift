import ArgumentParser
import Foundation
import ZIPFoundation

@testable import SwiftNASR

@main
struct SwiftNASR_Compare: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Compare TXT and CSV format outputs from SwiftNASR",
    discussion: """
      This tool parses NASR data in both TXT and CSV formats and performs comparisons:
      - High-level comparison of record counts
      - Detection of missing records in either format
      - Can load from local directories or download from the internet
      """
  )

  @Option(
    name: .shortAndLong,
    help: "Working directory for downloaded/cached files",
    transform: { URL(fileURLWithPath: $0) }
  )
  var workingDirectory = URL.currentDirectory().appendingPathComponent(".SwiftNASR_TestData")

  @Option(
    name: .long,
    help: "Path to local CSV directory (optional)",
    transform: { URL(fileURLWithPath: $0) }
  )
  var csvDirectory: URL?

  @Option(
    name: .long,
    help: "Path to local TXT distribution (optional)",
    transform: { URL(fileURLWithPath: $0) }
  )
  var txtPath: URL?

  @Option(
    name: .shortAndLong,
    help: "Output path for comparison report",
    transform: { URL(fileURLWithPath: $0) }
  )
  var output = URL(fileURLWithPath: "./comparison_report.json")

  @Flag(
    name: .shortAndLong,
    help: "Verbose output showing detailed differences"
  )
  var verbose = false

  @Option(
    name: .long,
    help: "Number of random records to sample for field comparison (default: 100)"
  )
  var sampleSize = 100

  private var txtDistributionURL: URL {
    workingDirectory.appendingPathComponent("distribution_txt.zip")
  }
  private var csvDistributionURL: URL {
    workingDirectory.appendingPathComponent("distribution_csv.zip")
  }

  lazy var txtNASR: NASR = {
    if let txtPath {
      if txtPath.pathExtension == "zip" {
        return NASR.fromLocalArchive(txtPath)
      }
      return NASR.fromLocalDirectory(txtPath, format: .txt)
    }
    if FileManager.default.fileExists(atPath: txtDistributionURL.path) {
      return NASR.fromLocalArchive(txtDistributionURL)
    }
    guard
      let downloadedNASR = NASR.fromInternetToFile(txtDistributionURL, activeAt: nil, format: .txt)
    else {
      fatalError("Failed to download TXT distribution")
    }
    return downloadedNASR
  }()

  lazy var csvNASR: NASR = {
    if let csvDirectory {
      return NASR.fromLocalDirectory(csvDirectory, format: .csv)
    }
    if FileManager.default.fileExists(atPath: csvDistributionURL.path) {
      // CSV distribution exists, but fromLocalArchive doesn't support format parameter
      // So we need to extract it to a directory first
      let tempDir = workingDirectory.appendingPathComponent("csv_extracted")
      // swiftlint:disable:next force_try
      try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      // swiftlint:disable:next force_try
      try! FileManager.default.unzipItem(at: csvDistributionURL, to: tempDir)
      return NASR.fromLocalDirectory(tempDir, format: .csv)
    }
    guard
      let downloadedNASR = NASR.fromInternetToFile(csvDistributionURL, activeAt: nil, format: .csv)
    else {
      fatalError("Failed to download CSV distribution")
    }
    return downloadedNASR
  }()

  mutating func run() async throws {
    print("SwiftNASR Format Comparison Tool")
    print("=================================\n")

    // Create working directory if needed
    try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

    // Load TXT format data
    print("Loading TXT format data...")
    print("  Source: \(txtPath?.path ?? "downloading from FAA website")")
    var txtData: ParseResults?
    do {
      try await txtNASR.load { progress in
        print("  Progress: \(Int(progress.fractionCompleted * 100))%")
      }
      print("  Parsing TXT data...")
      txtData = try await parseTXTData()
      print("  ✅ TXT data loaded successfully")
    } catch {
      print("  ❌ Failed to load TXT format: \(error)")
      print("  This may be due to the cycle data not being available for the current date.")
    }

    // Load CSV format data
    print("\nLoading CSV format data...")
    print("  Source: \(csvDirectory?.path ?? "downloading from FAA website")")
    var csvData: ParseResults?
    do {
      try await csvNASR.load { progress in
        print("  Progress: \(Int(progress.fractionCompleted * 100))%")
      }
      print("  Parsing CSV data...")
      csvData = try await parseCSVData()
      print("  ✅ CSV data loaded successfully")
    } catch {
      print("  ❌ Error loading CSV distribution: \(error)")
      print(
        "  This may be due to invalid data in the CSV files or the cycle data not being available."
      )
    }

    // Check if we have any data to compare
    guard let txtDataUnwrapped = txtData, let csvDataUnwrapped = csvData else {
      if txtData == nil && csvData == nil {
        print("\n❌ Could not load either TXT or CSV format data. Cannot perform comparison.")
        print("This may be due to the cycle data not being available for the current date.")
      } else if txtData != nil {
        print("\n⚠️  Only TXT format was loaded successfully. Cannot perform comparison.")
      } else if csvData != nil {
        print("\n⚠️  Only CSV format was loaded successfully. Cannot perform comparison.")
      }
      return
    }

    // Perform detailed comparison
    var comparisonResult = performDetailedComparison(
      txtData: txtDataUnwrapped,
      csvData: csvDataUnwrapped
    )

    // Display comparison summary
    print("\n" + String(repeating: "=", count: 80))
    print("COMPARISON SUMMARY")
    print(String(repeating: "=", count: 80))

    compareRecordCounts(
      "AIRPORTS",
      txt: txtDataUnwrapped.airportCount,
      csv: csvDataUnwrapped.airportCount,
      missingInCSV: comparisonResult.airportsMissingInCSV.count,
      missingInTXT: comparisonResult.airportsMissingInTXT.count
    )
    if !comparisonResult.airportsMissingInCSV.isEmpty {
      print(
        "  Missing in CSV: \(comparisonResult.airportsMissingInCSV.sorted().joined(separator: ", "))"
      )
    }
    if !comparisonResult.airportsMissingInTXT.isEmpty {
      print(
        "  Missing in TXT: \(comparisonResult.airportsMissingInTXT.sorted().joined(separator: ", "))"
      )
    }

    compareRecordCounts(
      "NAVAIDS",
      txt: txtDataUnwrapped.navaidCount,
      csv: csvDataUnwrapped.navaidCount,
      missingInCSV: comparisonResult.navaidsMissingInCSV.count,
      missingInTXT: comparisonResult.navaidsMissingInTXT.count
    )

    compareRecordCounts(
      "FSS",
      txt: txtDataUnwrapped.fssCount,
      csv: csvDataUnwrapped.fssCount,
      missingInCSV: comparisonResult.fssMissingInCSV.count,
      missingInTXT: comparisonResult.fssMissingInTXT.count
    )

    compareRecordCounts(
      "ARTCCs",
      txt: txtDataUnwrapped.artccCount,
      csv: csvDataUnwrapped.artccCount,
      missingInCSV: comparisonResult.artccMissingInCSV.count,
      missingInTXT: comparisonResult.artccMissingInTXT.count
    )

    // Perform random field-wise comparison
    print("\n" + String(repeating: "=", count: 80))
    print("RANDOM SAMPLE FIELD COMPARISON (\(sampleSize) samples per type)")
    print(String(repeating: "=", count: 80))

    performRandomFieldComparison(
      txtData: txtDataUnwrapped,
      csvData: csvDataUnwrapped,
      sampleSize: sampleSize,
      comparisonResult: &comparisonResult
    )

    // Display field discrepancy summary
    displayFieldDiscrepancySummary(comparisonResult.fieldDiscrepancies)

    // Create enhanced comparison report
    let report = EnhancedComparisonReport(
      timestamp: Date(),
      txtAirportCount: txtDataUnwrapped.airportCount,
      csvAirportCount: csvDataUnwrapped.airportCount,
      airportsMissingInCSV: comparisonResult.airportsMissingInCSV.count,
      airportsMissingInTXT: comparisonResult.airportsMissingInTXT.count,
      txtNavaidCount: txtDataUnwrapped.navaidCount,
      csvNavaidCount: csvDataUnwrapped.navaidCount,
      navaidsMissingInCSV: comparisonResult.navaidsMissingInCSV.count,
      navaidsMissingInTXT: comparisonResult.navaidsMissingInTXT.count,
      txtFSSCount: txtDataUnwrapped.fssCount,
      csvFSSCount: csvDataUnwrapped.fssCount,
      fssMissingInCSV: comparisonResult.fssMissingInCSV.count,
      fssMissingInTXT: comparisonResult.fssMissingInTXT.count,
      txtARTCCCount: txtDataUnwrapped.artccCount,
      csvARTCCCount: csvDataUnwrapped.artccCount,
      artccMissingInCSV: comparisonResult.artccMissingInCSV.count,
      artccMissingInTXT: comparisonResult.artccMissingInTXT.count,
      fieldDiscrepancies: comparisonResult.fieldDiscrepancies
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let reportData = try encoder.encode(report)
    try reportData.write(to: output)

    print("\n✅ Comparison report saved to: \(output.path)")
  }

  private mutating func parseTXTData() async throws -> ParseResults {
    var results = ParseResults()
    let verboseFlag = verbose

    // Parse all record types using NASR
    async let airports = try txtNASR.parse(
      .airports,
      withProgress: { _ in },
      errorHandler: { error in
        if verboseFlag {
          print("  TXT parsing error: \(error)")
        }
        return true  // Continue parsing
      }
    )
    async let artccs = try txtNASR.parse(
      .ARTCCFacilities,
      withProgress: { _ in },
      errorHandler: { error in
        if verboseFlag {
          print("  TXT parsing error: \(error)")
        }
        return true
      }
    )
    async let fsses = try txtNASR.parse(
      .flightServiceStations,
      withProgress: { _ in },
      errorHandler: { error in
        if verboseFlag {
          print("  TXT parsing error: \(error)")
        }
        return true
      }
    )
    async let navaids = try txtNASR.parse(
      .navaids,
      withProgress: { _ in },
      errorHandler: { error in
        if verboseFlag {
          print("  TXT parsing error: \(error)")
        }
        return true
      }
    )

    _ = try await [airports, artccs, fsses, navaids]

    // Get data from NASR
    results.airports = await txtNASR.data.airports ?? []
    results.airportCount = await txtNASR.data.airports?.count ?? 0

    // Convert Navaid array to dictionary using NavaidKey (ID + type)
    if let navaids = await txtNASR.data.navaids {
      for navaid in navaids {
        let key = NavaidKey(navaid: navaid)
        results.navaids[key] = navaid
      }
    }
    results.navaidCount = await txtNASR.data.navaids?.count ?? 0

    // Convert FSS array to dictionary using ID
    if let fsses = await txtNASR.data.FSSes {
      for fss in fsses {
        results.fssStations[fss.ID] = fss
      }
    }
    results.fssCount = await txtNASR.data.FSSes?.count ?? 0

    // Convert ARTCC array to dictionary using key
    if let artccs = await txtNASR.data.ARTCCs {
      for artcc in artccs {
        let key = ARTCCKey(center: artcc)
        results.artccFacilities[key] = artcc
      }
    }
    results.artccCount = await txtNASR.data.ARTCCs?.count ?? 0

    return results
  }

  private mutating func parseCSVData() async throws -> ParseResults {
    var results = ParseResults()
    let verboseFlag = verbose

    // Parse all record types using NASR
    async let airports = try csvNASR.parse(
      .airports,
      withProgress: { _ in },
      errorHandler: { error in
        if verboseFlag {
          print("  CSV parsing error: \(error)")
        }
        return true  // Continue parsing
      }
    )
    async let artccs = try csvNASR.parse(
      .ARTCCFacilities,
      withProgress: { _ in },
      errorHandler: { error in
        if verboseFlag {
          print("  CSV parsing error: \(error)")
        }
        return true
      }
    )
    async let fsses = try csvNASR.parse(
      .flightServiceStations,
      withProgress: { _ in },
      errorHandler: { error in
        if verboseFlag {
          print("  CSV parsing error: \(error)")
        }
        return true
      }
    )
    async let navaids = try csvNASR.parse(
      .navaids,
      withProgress: { _ in },
      errorHandler: { error in
        if verboseFlag {
          print("  CSV parsing error: \(error)")
        }
        return true
      }
    )

    _ = try await [airports, artccs, fsses, navaids]

    // Get data from NASR
    results.airports = await csvNASR.data.airports ?? []
    results.airportCount = await csvNASR.data.airports?.count ?? 0

    // Convert Navaid array to dictionary using NavaidKey (ID + type)
    if let navaids = await csvNASR.data.navaids {
      for navaid in navaids {
        let key = NavaidKey(navaid: navaid)
        results.navaids[key] = navaid
      }
    }
    results.navaidCount = await csvNASR.data.navaids?.count ?? 0

    // Convert FSS array to dictionary using ID
    if let fsses = await csvNASR.data.FSSes {
      for fss in fsses {
        results.fssStations[fss.ID] = fss
      }
    }
    results.fssCount = await csvNASR.data.FSSes?.count ?? 0

    // Convert ARTCC array to dictionary using key
    if let artccs = await csvNASR.data.ARTCCs {
      for artcc in artccs {
        let key = ARTCCKey(center: artcc)
        results.artccFacilities[key] = artcc
      }
    }
    results.artccCount = await csvNASR.data.ARTCCs?.count ?? 0

    return results
  }

  private func compareRecordCounts(
    _ name: String,
    txt: Int,
    csv: Int,
    missingInCSV: Int,
    missingInTXT: Int
  ) {
    let diff = abs(txt - csv)
    let percentDiff = txt > 0 ? Double(diff) / Double(txt) * 100 : 0
    let status = diff == 0 ? "✅" : (percentDiff < 5 ? "⚠️" : "❌")

    print("\n\(name):")
    print("  TXT Records: \(txt)")
    print("  CSV Records: \(csv)")
    print("  Total Difference: \(diff) (\(String(format: "%.1f", percentDiff))%) \(status)")
    print("  Records only in TXT (missing in CSV): \(missingInCSV)")
    print("  Records only in CSV (missing in TXT): \(missingInTXT)")
  }

  private func performDetailedComparison(txtData: ParseResults, csvData: ParseResults)
    -> DetailedComparisonResult
  {
    var result = DetailedComparisonResult()

    // Find missing airports
    let txtAirportIDs = Set(txtData.airports.map(\.LID))
    let csvAirportIDs = Set(csvData.airports.map(\.LID))
    result.airportsMissingInCSV = txtAirportIDs.subtracting(csvAirportIDs)
    result.airportsMissingInTXT = csvAirportIDs.subtracting(txtAirportIDs)

    // Find missing navaids
    let txtNavaidIDs = Set(txtData.navaids.keys)
    let csvNavaidIDs = Set(csvData.navaids.keys)
    result.navaidsMissingInCSV = txtNavaidIDs.subtracting(csvNavaidIDs)
    result.navaidsMissingInTXT = csvNavaidIDs.subtracting(txtNavaidIDs)

    // Find missing FSS
    let txtFSSIDs = Set(txtData.fssStations.keys)
    let csvFSSIDs = Set(csvData.fssStations.keys)
    result.fssMissingInCSV = txtFSSIDs.subtracting(csvFSSIDs)
    result.fssMissingInTXT = csvFSSIDs.subtracting(txtFSSIDs)

    // Find missing ARTCCs
    let txtARTCCKeys = Set(txtData.artccFacilities.keys)
    let csvARTCCKeys = Set(csvData.artccFacilities.keys)
    result.artccMissingInCSV = txtARTCCKeys.subtracting(csvARTCCKeys)
    result.artccMissingInTXT = csvARTCCKeys.subtracting(txtARTCCKeys)

    return result
  }

  private func performRandomFieldComparison(
    txtData: ParseResults,
    csvData: ParseResults,
    sampleSize: Int,
    comparisonResult: inout DetailedComparisonResult
  ) {
    var fieldDiscrepancies: [FieldDiscrepancy] = []

    // Compare random airports
    print("\nAirports Field Comparison:")
    let commonAirports = txtData.airports
      .filter { airport in csvData.airports.contains { $0.LID == airport.LID } }
      .shuffled()
      .prefix(sampleSize)

    var airportDiscrepancyCount = 0
    for txtAirport in commonAirports {
      if let csvAirport = csvData.airports.first(where: { $0.LID == txtAirport.LID }) {
        let discrepancies = compareAirportFields(txt: txtAirport, csv: csvAirport)
        if !discrepancies.isEmpty {
          airportDiscrepancyCount += 1
          if verbose {
            print("  \(txtAirport.LID):")
            for disc in discrepancies {
              print("    - \(disc.field): TXT='\(disc.txtValue)' CSV='\(disc.csvValue)'")
            }
          }
          fieldDiscrepancies.append(contentsOf: discrepancies)
        }
      }
    }
    print(
      "  Checked \(commonAirports.count) airports, found discrepancies in \(airportDiscrepancyCount)"
    )

    // Compare random navaids
    print("\nNavaids Field Comparison:")
    let commonNavaids = Array(txtData.navaids.keys)
      .filter { key in csvData.navaids[key] != nil }
      .shuffled()
      .prefix(sampleSize)

    var navaidDiscrepancyCount = 0
    for navaidKey in commonNavaids {
      if let txtNavaid = txtData.navaids[navaidKey],
        let csvNavaid = csvData.navaids[navaidKey]
      {
        let discrepancies = compareNavaidFields(txt: txtNavaid, csv: csvNavaid)
        if !discrepancies.isEmpty {
          navaidDiscrepancyCount += 1
          if verbose {
            print("  \(navaidKey.ID) (\(txtNavaid.type.rawValue)) - \(navaidKey.city):")
            for disc in discrepancies {
              print("    - \(disc.field): TXT='\(disc.txtValue)' CSV='\(disc.csvValue)'")
            }
          }
          fieldDiscrepancies.append(contentsOf: discrepancies)
        }
      }
    }
    print(
      "  Checked \(commonNavaids.count) navaids, found discrepancies in \(navaidDiscrepancyCount)"
    )

    // Compare random FSS
    print("\nFSS Field Comparison:")
    let commonFSS = Array(txtData.fssStations.keys)
      .filter { id in csvData.fssStations[id] != nil }
      .shuffled()
      .prefix(sampleSize)

    var fssDiscrepancyCount = 0
    for fssID in commonFSS {
      if let txtFSS = txtData.fssStations[fssID],
        let csvFSS = csvData.fssStations[fssID]
      {
        let discrepancies = compareFSSFields(txt: txtFSS, csv: csvFSS)
        if !discrepancies.isEmpty {
          fssDiscrepancyCount += 1
          if verbose {
            print("  \(fssID):")
            for disc in discrepancies {
              print("    - \(disc.field): TXT='\(disc.txtValue)' CSV='\(disc.csvValue)'")
            }
          }
          fieldDiscrepancies.append(contentsOf: discrepancies)
        }
      }
    }
    print("  Checked \(commonFSS.count) FSS, found discrepancies in \(fssDiscrepancyCount)")

    // Compare random ARTCCs
    print("\nARTCC Field Comparison:")
    let commonARTCC = Array(txtData.artccFacilities.keys)
      .filter { key in csvData.artccFacilities[key] != nil }
      .shuffled()
      .prefix(sampleSize)

    var artccDiscrepancyCount = 0
    for artccKey in commonARTCC {
      if let txtARTCC = txtData.artccFacilities[artccKey],
        let csvARTCC = csvData.artccFacilities[artccKey]
      {
        let discrepancies = compareARTCCFields(txt: txtARTCC, csv: csvARTCC)
        if !discrepancies.isEmpty {
          artccDiscrepancyCount += 1
          if verbose {
            print("  \(artccKey.ID):")
            for disc in discrepancies {
              print("    - \(disc.field): TXT='\(disc.txtValue)' CSV='\(disc.csvValue)'")
            }
          }
          fieldDiscrepancies.append(contentsOf: discrepancies)
        }
      }
    }
    print("  Checked \(commonARTCC.count) ARTCCs, found discrepancies in \(artccDiscrepancyCount)")

    // Store all collected field discrepancies
    comparisonResult.fieldDiscrepancies = fieldDiscrepancies
  }

  // MARK: - Field Comparison Helpers

  private func compareString(
    _ recordType: String,
    _ recordID: String,
    _ field: String,
    _ txtValue: String?,
    _ csvValue: String?
  ) -> FieldDiscrepancy? {
    guard txtValue != csvValue else { return nil }
    return FieldDiscrepancy(
      recordType: recordType,
      recordID: recordID,
      field: field,
      txtValue: txtValue ?? "nil",
      csvValue: csvValue ?? "nil"
    )
  }

  private func compareBool(
    _ recordType: String,
    _ recordID: String,
    _ field: String,
    _ txtValue: Bool?,
    _ csvValue: Bool?
  ) -> FieldDiscrepancy? {
    guard txtValue != csvValue else { return nil }
    return FieldDiscrepancy(
      recordType: recordType,
      recordID: recordID,
      field: field,
      txtValue: txtValue.map { String($0) } ?? "nil",
      csvValue: csvValue.map { String($0) } ?? "nil"
    )
  }

  private func compareInt(
    _ recordType: String,
    _ recordID: String,
    _ field: String,
    _ txtValue: Int?,
    _ csvValue: Int?
  ) -> FieldDiscrepancy? {
    guard txtValue != csvValue else { return nil }
    return FieldDiscrepancy(
      recordType: recordType,
      recordID: recordID,
      field: field,
      txtValue: txtValue.map { String($0) } ?? "nil",
      csvValue: csvValue.map { String($0) } ?? "nil"
    )
  }

  private func compareUInt(
    _ recordType: String,
    _ recordID: String,
    _ field: String,
    _ txtValue: UInt?,
    _ csvValue: UInt?
  ) -> FieldDiscrepancy? {
    guard txtValue != csvValue else { return nil }
    return FieldDiscrepancy(
      recordType: recordType,
      recordID: recordID,
      field: field,
      txtValue: txtValue.map { String($0) } ?? "nil",
      csvValue: csvValue.map { String($0) } ?? "nil"
    )
  }

  private func compareFloat(
    _ recordType: String,
    _ recordID: String,
    _ field: String,
    _ txtValue: Float?,
    _ csvValue: Float?,
    tolerance: Float = 0.0001
  ) -> FieldDiscrepancy? {
    if let t = txtValue, let c = csvValue {
      guard abs(t - c) > tolerance else { return nil }
    } else if txtValue == nil && csvValue == nil {
      return nil
    }
    return FieldDiscrepancy(
      recordType: recordType,
      recordID: recordID,
      field: field,
      txtValue: txtValue.map { String($0) } ?? "nil",
      csvValue: csvValue.map { String($0) } ?? "nil"
    )
  }

  private func compareDate(
    _ recordType: String,
    _ recordID: String,
    _ field: String,
    _ txtValue: Date?,
    _ csvValue: Date?
  ) -> FieldDiscrepancy? {
    guard txtValue != csvValue else { return nil }
    let formatter = ISO8601DateFormatter()
    return FieldDiscrepancy(
      recordType: recordType,
      recordID: recordID,
      field: field,
      txtValue: txtValue.map { formatter.string(from: $0) } ?? "nil",
      csvValue: csvValue.map { formatter.string(from: $0) } ?? "nil"
    )
  }

  private func compareEnum<T: RawRepresentable>(
    _ recordType: String,
    _ recordID: String,
    _ field: String,
    _ txtValue: T?,
    _ csvValue: T?
  ) -> FieldDiscrepancy? where T.RawValue == String {
    guard txtValue?.rawValue != csvValue?.rawValue else { return nil }
    return FieldDiscrepancy(
      recordType: recordType,
      recordID: recordID,
      field: field,
      txtValue: txtValue?.rawValue ?? "nil",
      csvValue: csvValue?.rawValue ?? "nil"
    )
  }

  private func compareArray<T: Equatable & CustomStringConvertible>(
    _ recordType: String,
    _ recordID: String,
    _ field: String,
    _ txtValue: [T],
    _ csvValue: [T]
  ) -> FieldDiscrepancy? {
    guard txtValue != csvValue else { return nil }
    return FieldDiscrepancy(
      recordType: recordType,
      recordID: recordID,
      field: field,
      txtValue: txtValue.map { String(describing: $0) }.joined(separator: ","),
      csvValue: csvValue.map { String(describing: $0) }.joined(separator: ",")
    )
  }

  // MARK: - Airport Field Comparison

  private func compareAirportFields(txt: Airport, csv: Airport) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []
    let rt = "Airport"
    let id = txt.LID

    // Basic identifiers
    if let d = compareString(rt, id, "name", txt.name, csv.name) { discrepancies.append(d) }
    if let d = compareString(rt, id, "LID", txt.LID, csv.LID) { discrepancies.append(d) }
    if let d = compareString(rt, id, "ICAOIdentifier", txt.ICAOIdentifier, csv.ICAOIdentifier) {
      discrepancies.append(d)
    }
    if let d = compareEnum(rt, id, "facilityType", txt.facilityType, csv.facilityType) {
      discrepancies.append(d)
    }

    // Demographics
    if let d = compareEnum(rt, id, "FAARegion", txt.FAARegion, csv.FAARegion) {
      discrepancies.append(d)
    }
    if let d = compareString(
      rt,
      id,
      "FAAFieldOfficeCode",
      txt.FAAFieldOfficeCode,
      csv.FAAFieldOfficeCode
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "stateCode", txt.stateCode, csv.stateCode) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "county", txt.county, csv.county) { discrepancies.append(d) }
    if let d = compareString(rt, id, "countyStateCode", txt.countyStateCode, csv.countyStateCode) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "city", txt.city, csv.city) { discrepancies.append(d) }

    // Ownership
    if let d = compareEnum(rt, id, "ownership", txt.ownership, csv.ownership) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "publicUse", txt.publicUse, csv.publicUse) {
      discrepancies.append(d)
    }

    // Location - coordinates with tolerance
    if let d = compareFloat(
      rt,
      id,
      "latitude",
      txt.referencePoint.latitude,
      csv.referencePoint.latitude
    ) {
      discrepancies.append(d)
    }
    if let d = compareFloat(
      rt,
      id,
      "longitude",
      txt.referencePoint.longitude,
      csv.referencePoint.longitude
    ) {
      discrepancies.append(d)
    }
    if let d = compareFloat(
      rt,
      id,
      "elevation",
      txt.referencePoint.elevation,
      csv.referencePoint.elevation,
      tolerance: 1.0
    ) {
      discrepancies.append(d)
    }

    // Location determination
    if let d = compareEnum(
      rt,
      id,
      "referencePointDeterminationMethod",
      txt.referencePointDeterminationMethod,
      csv.referencePointDeterminationMethod
    ) {
      discrepancies.append(d)
    }
    if let d = compareEnum(
      rt,
      id,
      "elevationDeterminationMethod",
      txt.elevationDeterminationMethod,
      csv.elevationDeterminationMethod
    ) {
      discrepancies.append(d)
    }

    // Magnetic variation
    if let d = compareInt(rt, id, "magneticVariation", txt.magneticVariation, csv.magneticVariation)
    {
      discrepancies.append(d)
    }
    if let d = compareDate(
      rt,
      id,
      "magneticVariationEpoch",
      txt.magneticVariationEpoch,
      csv.magneticVariationEpoch
    ) {
      discrepancies.append(d)
    }

    // Traffic and charts
    if let d = compareInt(
      rt,
      id,
      "trafficPatternAltitude",
      txt.trafficPatternAltitude,
      csv.trafficPatternAltitude
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "sectionalChart", txt.sectionalChart, csv.sectionalChart) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      rt,
      id,
      "distanceCityToAirport",
      txt.distanceCityToAirport,
      csv.distanceCityToAirport
    ) {
      discrepancies.append(d)
    }
    if let d = compareEnum(
      rt,
      id,
      "directionCityToAirport",
      txt.directionCityToAirport,
      csv.directionCityToAirport
    ) {
      discrepancies.append(d)
    }
    if let d = compareFloat(rt, id, "landArea", txt.landArea, csv.landArea, tolerance: 1.0) {
      discrepancies.append(d)
    }

    // FAA Services
    // Note: boundaryARTCCID not compared - not available in CSV format
    if let d = compareString(
      rt,
      id,
      "responsibleARTCCID",
      txt.responsibleARTCCID,
      csv.responsibleARTCCID
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "tieInFSSID", txt.tieInFSSID, csv.tieInFSSID) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      rt,
      id,
      "tieInFSSOnStation",
      txt.tieInFSSOnStation,
      csv.tieInFSSOnStation
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "alternateFSSID", txt.alternateFSSID, csv.alternateFSSID) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "NOTAMIssuerID", txt.NOTAMIssuerID, csv.NOTAMIssuerID) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "NOTAMDAvailable", txt.NOTAMDAvailable, csv.NOTAMDAvailable) {
      discrepancies.append(d)
    }

    // Federal Status
    if let d = compareDate(rt, id, "activationDate", txt.activationDate, csv.activationDate) {
      discrepancies.append(d)
    }
    if let d = compareEnum(rt, id, "status", txt.status, csv.status) { discrepancies.append(d) }
    if let d = compareEnum(
      rt,
      id,
      "airspaceAnalysisDetermination",
      txt.airspaceAnalysisDetermination,
      csv.airspaceAnalysisDetermination
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      rt,
      id,
      "customsEntryAirport",
      txt.customsEntryAirport,
      csv.customsEntryAirport
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      rt,
      id,
      "customsLandingRightsAirport",
      txt.customsLandingRightsAirport,
      csv.customsLandingRightsAirport
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      rt,
      id,
      "jointUseAgreement",
      txt.jointUseAgreement,
      csv.jointUseAgreement
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      rt,
      id,
      "militaryLandingRights",
      txt.militaryLandingRights,
      csv.militaryLandingRights
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      rt,
      id,
      "minimumOperationalNetwork",
      txt.minimumOperationalNetwork,
      csv.minimumOperationalNetwork
    ) {
      discrepancies.append(d)
    }

    // Inspection
    if let d = compareEnum(rt, id, "inspectionMethod", txt.inspectionMethod, csv.inspectionMethod) {
      discrepancies.append(d)
    }
    if let d = compareEnum(rt, id, "inspectionAgency", txt.inspectionAgency, csv.inspectionAgency) {
      discrepancies.append(d)
    }
    if let d = compareDate(
      rt,
      id,
      "lastPhysicalInspectionDate",
      txt.lastPhysicalInspectionDate,
      csv.lastPhysicalInspectionDate
    ) {
      discrepancies.append(d)
    }
    if let d = compareDate(
      rt,
      id,
      "lastInformationRequestCompletedDate",
      txt.lastInformationRequestCompletedDate,
      csv.lastInformationRequestCompletedDate
    ) {
      discrepancies.append(d)
    }

    // Services
    if let d = compareEnum(
      rt,
      id,
      "airframeRepairAvailable",
      txt.airframeRepairAvailable,
      csv.airframeRepairAvailable
    ) {
      discrepancies.append(d)
    }
    if let d = compareEnum(
      rt,
      id,
      "powerplantRepairAvailable",
      txt.powerplantRepairAvailable,
      csv.powerplantRepairAvailable
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      rt,
      id,
      "contractFuelAvailable",
      txt.contractFuelAvailable,
      csv.contractFuelAvailable
    ) {
      discrepancies.append(d)
    }

    // Facilities
    if let d = compareEnum(
      rt,
      id,
      "airportLightingSchedule",
      txt.airportLightingSchedule,
      csv.airportLightingSchedule
    ) {
      discrepancies.append(d)
    }
    if let d = compareEnum(
      rt,
      id,
      "beaconLightingSchedule",
      txt.beaconLightingSchedule,
      csv.beaconLightingSchedule
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "controlTower", txt.controlTower, csv.controlTower) {
      discrepancies.append(d)
    }
    if let d = compareUInt(rt, id, "UNICOMFrequency", txt.UNICOMFrequency, csv.UNICOMFrequency) {
      discrepancies.append(d)
    }
    if let d = compareUInt(rt, id, "CTAF", txt.CTAF, csv.CTAF) { discrepancies.append(d) }
    if let d = compareEnum(rt, id, "segmentedCircle", txt.segmentedCircle, csv.segmentedCircle) {
      discrepancies.append(d)
    }
    if let d = compareEnum(rt, id, "beaconColor", txt.beaconColor, csv.beaconColor) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "landingFee", txt.landingFee, csv.landingFee) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "medicalUse", txt.medicalUse, csv.medicalUse) {
      discrepancies.append(d)
    }
    if let d = compareEnum(rt, id, "windIndicator", txt.windIndicator, csv.windIndicator) {
      discrepancies.append(d)
    }

    // Based aircraft
    if let d = compareUInt(
      rt,
      id,
      "basedSingleEngineGA",
      txt.basedSingleEngineGA,
      csv.basedSingleEngineGA
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      rt,
      id,
      "basedMultiEngineGA",
      txt.basedMultiEngineGA,
      csv.basedMultiEngineGA
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(rt, id, "basedJetGA", txt.basedJetGA, csv.basedJetGA) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      rt,
      id,
      "basedHelicopterGA",
      txt.basedHelicopterGA,
      csv.basedHelicopterGA
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      rt,
      id,
      "basedOperationalGliders",
      txt.basedOperationalGliders,
      csv.basedOperationalGliders
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      rt,
      id,
      "basedOperationalMilitary",
      txt.basedOperationalMilitary,
      csv.basedOperationalMilitary
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(rt, id, "basedUltralights", txt.basedUltralights, csv.basedUltralights) {
      discrepancies.append(d)
    }

    // Annual operations
    if let d = compareUInt(
      rt,
      id,
      "annualCommercialOps",
      txt.annualCommercialOps,
      csv.annualCommercialOps
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      rt,
      id,
      "annualCommuterOps",
      txt.annualCommuterOps,
      csv.annualCommuterOps
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(rt, id, "annualAirTaxiOps", txt.annualAirTaxiOps, csv.annualAirTaxiOps) {
      discrepancies.append(d)
    }
    if let d = compareUInt(rt, id, "annualLocalGAOps", txt.annualLocalGAOps, csv.annualLocalGAOps) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      rt,
      id,
      "annualTransientGAOps",
      txt.annualTransientGAOps,
      csv.annualTransientGAOps
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      rt,
      id,
      "annualMilitaryOps",
      txt.annualMilitaryOps,
      csv.annualMilitaryOps
    ) {
      discrepancies.append(d)
    }
    if let d = compareDate(
      rt,
      id,
      "annualPeriodEndDate",
      txt.annualPeriodEndDate,
      csv.annualPeriodEndDate
    ) {
      discrepancies.append(d)
    }

    // Position/Elevation source
    if let d = compareString(rt, id, "positionSource", txt.positionSource, csv.positionSource) {
      discrepancies.append(d)
    }
    if let d = compareDate(
      rt,
      id,
      "positionSourceDate",
      txt.positionSourceDate,
      csv.positionSourceDate
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "elevationSource", txt.elevationSource, csv.elevationSource) {
      discrepancies.append(d)
    }
    if let d = compareDate(
      rt,
      id,
      "elevationSourceDate",
      txt.elevationSourceDate,
      csv.elevationSourceDate
    ) {
      discrepancies.append(d)
    }

    // --- Gross Comparison: Runway Count ---
    if txt.runways.count != csv.runways.count {
      discrepancies.append(
        FieldDiscrepancy(
          recordType: rt,
          recordID: id,
          field: "runways.count",
          txtValue: String(txt.runways.count),
          csvValue: String(csv.runways.count)
        )
      )
    }

    // --- Gross Comparison: Attendance Schedule Count ---
    if txt.attendanceSchedule.count != csv.attendanceSchedule.count {
      discrepancies.append(
        FieldDiscrepancy(
          recordType: rt,
          recordID: id,
          field: "attendanceSchedule.count",
          txtValue: String(txt.attendanceSchedule.count),
          csvValue: String(csv.attendanceSchedule.count)
        )
      )
    }

    // --- Gross Comparison: Owner presence ---
    let txtHasOwner = txt.owner != nil
    let csvHasOwner = csv.owner != nil
    if txtHasOwner != csvHasOwner {
      discrepancies.append(
        FieldDiscrepancy(
          recordType: rt,
          recordID: id,
          field: "owner.present",
          txtValue: String(txtHasOwner),
          csvValue: String(csvHasOwner)
        )
      )
    }

    // --- Gross Comparison: Manager presence ---
    let txtHasManager = txt.manager != nil
    let csvHasManager = csv.manager != nil
    if txtHasManager != csvHasManager {
      discrepancies.append(
        FieldDiscrepancy(
          recordType: rt,
          recordID: id,
          field: "manager.present",
          txtValue: String(txtHasManager),
          csvValue: String(csvHasManager)
        )
      )
    }

    // --- Owner Field Comparison ---
    if let txtOwner = txt.owner, let csvOwner = csv.owner {
      discrepancies.append(contentsOf: comparePersonFields(rt, id, "owner", txtOwner, csvOwner))
    }

    // --- Manager Field Comparison ---
    if let txtManager = txt.manager, let csvManager = csv.manager {
      discrepancies.append(
        contentsOf: comparePersonFields(rt, id, "manager", txtManager, csvManager)
      )
    }

    // --- Attendance Schedule Field Comparison ---
    discrepancies.append(
      contentsOf: compareAttendanceSchedules(rt, id, txt.attendanceSchedule, csv.attendanceSchedule)
    )

    // --- Runway and Runway End Field Comparisons ---
    discrepancies.append(contentsOf: compareRunways(rt, id, txt.runways, csv.runways))

    return discrepancies
  }

  // MARK: - Person Field Comparison

  private func comparePersonFields(
    _ recordType: String,
    _ recordID: String,
    _ prefix: String,
    _ txt: Airport.Person,
    _ csv: Airport.Person
  ) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []

    if let d = compareString(recordType, recordID, "\(prefix).name", txt.name, csv.name) {
      discrepancies.append(d)
    }
    if let d = compareString(recordType, recordID, "\(prefix).address1", txt.address1, csv.address1)
    {
      discrepancies.append(d)
    }
    if let d = compareString(recordType, recordID, "\(prefix).address2", txt.address2, csv.address2)
    {
      discrepancies.append(d)
    }
    if let d = compareString(recordType, recordID, "\(prefix).phone", txt.phone, csv.phone) {
      discrepancies.append(d)
    }

    return discrepancies
  }

  // MARK: - Attendance Schedule Comparison

  private func compareAttendanceSchedules(
    _ recordType: String,
    _ recordID: String,
    _ txtSchedules: [AttendanceSchedule],
    _ csvSchedules: [AttendanceSchedule]
  ) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []

    // Compare each schedule by index (order matters)
    let maxCount = max(txtSchedules.count, csvSchedules.count)
    for i in 0..<maxCount {
      let txtSchedule = i < txtSchedules.count ? txtSchedules[i] : nil
      let csvSchedule = i < csvSchedules.count ? csvSchedules[i] : nil

      let txtValue = formatAttendanceSchedule(txtSchedule)
      let csvValue = formatAttendanceSchedule(csvSchedule)

      if txtValue != csvValue {
        discrepancies.append(
          FieldDiscrepancy(
            recordType: recordType,
            recordID: recordID,
            field: "attendanceSchedule[\(i)]",
            txtValue: txtValue,
            csvValue: csvValue
          )
        )
      }
    }

    return discrepancies
  }

  private func formatAttendanceSchedule(_ schedule: AttendanceSchedule?) -> String {
    guard let schedule else { return "nil" }
    switch schedule {
      case let .components(monthly, daily, hourly):
        return "components(\(monthly),\(daily),\(hourly))"
      case .custom(let text):
        return "custom(\(text))"
    }
  }

  // MARK: - Runway Comparison

  private func compareRunways(
    _ recordType: String,
    _ recordID: String,
    _ txtRunways: [Runway],
    _ csvRunways: [Runway]
  ) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []

    // Create dictionaries keyed by runway identification
    let txtDict = Dictionary(uniqueKeysWithValues: txtRunways.map { ($0.identification, $0) })
    let csvDict = Dictionary(uniqueKeysWithValues: csvRunways.map { ($0.identification, $0) })

    // Find runways missing in each format
    let txtIDs = Set(txtDict.keys)
    let csvIDs = Set(csvDict.keys)
    let missingInCSV = txtIDs.subtracting(csvIDs)
    let missingInTXT = csvIDs.subtracting(txtIDs)

    for rwyID in missingInCSV {
      discrepancies.append(
        FieldDiscrepancy(
          recordType: recordType,
          recordID: recordID,
          field: "runway[\(rwyID)].missing",
          txtValue: "present",
          csvValue: "nil"
        )
      )
    }

    for rwyID in missingInTXT {
      discrepancies.append(
        FieldDiscrepancy(
          recordType: recordType,
          recordID: recordID,
          field: "runway[\(rwyID)].missing",
          txtValue: "nil",
          csvValue: "present"
        )
      )
    }

    // Compare common runways
    let commonIDs = txtIDs.intersection(csvIDs)
    for rwyID in commonIDs {
      guard let txtRunway = txtDict[rwyID], let csvRunway = csvDict[rwyID] else { continue }
      discrepancies.append(
        contentsOf: compareRunwayFields(recordType, recordID, rwyID, txtRunway, csvRunway)
      )
    }

    return discrepancies
  }

  private func compareRunwayFields(
    _ recordType: String,
    _ recordID: String,
    _ rwyID: String,
    _ txt: Runway,
    _ csv: Runway
  ) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []
    let prefix = "runway[\(rwyID)]"

    // Basic runway fields
    if let d = compareUInt(recordType, recordID, "\(prefix).length", txt.length, csv.length) {
      discrepancies.append(d)
    }
    if let d = compareUInt(recordType, recordID, "\(prefix).width", txt.width, csv.width) {
      discrepancies.append(d)
    }
    if let d = compareString(
      recordType,
      recordID,
      "\(prefix).lengthSource",
      txt.lengthSource,
      csv.lengthSource
    ) {
      discrepancies.append(d)
    }
    if let d = compareDate(
      recordType,
      recordID,
      "\(prefix).lengthSourceDate",
      txt.lengthSourceDate,
      csv.lengthSourceDate
    ) {
      discrepancies.append(d)
    }

    // Materials comparison (as sorted joined string)
    let txtMaterials = txt.materials.map(\.rawValue).sorted().joined(separator: ",")
    let csvMaterials = csv.materials.map(\.rawValue).sorted().joined(separator: ",")
    if txtMaterials != csvMaterials {
      discrepancies.append(
        FieldDiscrepancy(
          recordType: recordType,
          recordID: recordID,
          field: "\(prefix).materials",
          txtValue: txtMaterials.isEmpty ? "nil" : txtMaterials,
          csvValue: csvMaterials.isEmpty ? "nil" : csvMaterials
        )
      )
    }

    if let d = compareEnum(
      recordType,
      recordID,
      "\(prefix).condition",
      txt.condition,
      csv.condition
    ) {
      discrepancies.append(d)
    }
    if let d = compareEnum(
      recordType,
      recordID,
      "\(prefix).treatment",
      txt.treatment,
      csv.treatment
    ) {
      discrepancies.append(d)
    }
    if let d = compareEnum(
      recordType,
      recordID,
      "\(prefix).edgeLightsIntensity",
      txt.edgeLightsIntensity,
      csv.edgeLightsIntensity
    ) {
      discrepancies.append(d)
    }

    // Pavement classification
    discrepancies.append(
      contentsOf: comparePavementClassification(
        recordType,
        recordID,
        prefix,
        txt.pavementClassification,
        csv.pavementClassification
      )
    )

    // Weight bearing capacities
    if let d = compareUInt(
      recordType,
      recordID,
      "\(prefix).singleWheelWeightBearingCapacity",
      txt.singleWheelWeightBearingCapacity,
      csv.singleWheelWeightBearingCapacity
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      recordType,
      recordID,
      "\(prefix).dualWheelWeightBearingCapacity",
      txt.dualWheelWeightBearingCapacity,
      csv.dualWheelWeightBearingCapacity
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      recordType,
      recordID,
      "\(prefix).tandemDualWheelWeightBearingCapacity",
      txt.tandemDualWheelWeightBearingCapacity,
      csv.tandemDualWheelWeightBearingCapacity
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      recordType,
      recordID,
      "\(prefix).doubleTandemDualWheelWeightBearingCapacity",
      txt.doubleTandemDualWheelWeightBearingCapacity,
      csv.doubleTandemDualWheelWeightBearingCapacity
    ) {
      discrepancies.append(d)
    }

    // Compare base end
    discrepancies.append(
      contentsOf: compareRunwayEndFields(
        recordType,
        recordID,
        "\(prefix).baseEnd",
        txt.baseEnd,
        csv.baseEnd
      )
    )

    // Compare reciprocal end
    if txt.reciprocalEnd != nil || csv.reciprocalEnd != nil {
      if let txtEnd = txt.reciprocalEnd, let csvEnd = csv.reciprocalEnd {
        discrepancies.append(
          contentsOf: compareRunwayEndFields(
            recordType,
            recordID,
            "\(prefix).reciprocalEnd",
            txtEnd,
            csvEnd
          )
        )
      } else {
        discrepancies.append(
          FieldDiscrepancy(
            recordType: recordType,
            recordID: recordID,
            field: "\(prefix).reciprocalEnd.present",
            txtValue: txt.reciprocalEnd != nil ? "present" : "nil",
            csvValue: csv.reciprocalEnd != nil ? "present" : "nil"
          )
        )
      }
    }

    return discrepancies
  }

  private func comparePavementClassification(
    _ recordType: String,
    _ recordID: String,
    _ prefix: String,
    _ txt: Runway.PavementClassification?,
    _ csv: Runway.PavementClassification?
  ) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []
    let pcnPrefix = "\(prefix).pavementClassification"

    if txt != nil || csv != nil {
      if let txtPCN = txt, let csvPCN = csv {
        if let d = compareUInt(
          recordType,
          recordID,
          "\(pcnPrefix).number",
          txtPCN.number,
          csvPCN.number
        ) {
          discrepancies.append(d)
        }
        if let d = compareEnum(recordType, recordID, "\(pcnPrefix).type", txtPCN.type, csvPCN.type)
        {
          discrepancies.append(d)
        }
        if let d = compareEnum(
          recordType,
          recordID,
          "\(pcnPrefix).subgradeStrengthCategory",
          txtPCN.subgradeStrengthCategory,
          csvPCN.subgradeStrengthCategory
        ) {
          discrepancies.append(d)
        }
        if let d = compareEnum(
          recordType,
          recordID,
          "\(pcnPrefix).tirePressureLimit",
          txtPCN.tirePressureLimit,
          csvPCN.tirePressureLimit
        ) {
          discrepancies.append(d)
        }
        if let d = compareEnum(
          recordType,
          recordID,
          "\(pcnPrefix).determinationMethod",
          txtPCN.determinationMethod,
          csvPCN.determinationMethod
        ) {
          discrepancies.append(d)
        }
      } else {
        discrepancies.append(
          FieldDiscrepancy(
            recordType: recordType,
            recordID: recordID,
            field: "\(pcnPrefix).present",
            txtValue: txt != nil ? "present" : "nil",
            csvValue: csv != nil ? "present" : "nil"
          )
        )
      }
    }

    return discrepancies
  }

  // MARK: - Runway End Comparison

  private func compareRunwayEndFields(
    _ recordType: String,
    _ recordID: String,
    _ prefix: String,
    _ txt: RunwayEnd,
    _ csv: RunwayEnd
  ) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []

    // Basic identifiers
    if let d = compareString(recordType, recordID, "\(prefix).ID", txt.ID, csv.ID) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      recordType,
      recordID,
      "\(prefix).trueHeading",
      txt.trueHeading,
      csv.trueHeading
    ) {
      discrepancies.append(d)
    }
    if let d = compareEnum(
      recordType,
      recordID,
      "\(prefix).instrumentLandingSystem",
      txt.instrumentLandingSystem,
      csv.instrumentLandingSystem
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      recordType,
      recordID,
      "\(prefix).rightTraffic",
      txt.rightTraffic,
      csv.rightTraffic
    ) {
      discrepancies.append(d)
    }

    // Markings
    if let d = compareEnum(recordType, recordID, "\(prefix).marking", txt.marking, csv.marking) {
      discrepancies.append(d)
    }
    if let d = compareEnum(
      recordType,
      recordID,
      "\(prefix).markingCondition",
      txt.markingCondition,
      csv.markingCondition
    ) {
      discrepancies.append(d)
    }

    // Threshold location
    if txt.threshold != nil || csv.threshold != nil {
      if let d = compareFloat(
        recordType,
        recordID,
        "\(prefix).threshold.latitude",
        txt.threshold?.latitude,
        csv.threshold?.latitude
      ) {
        discrepancies.append(d)
      }
      if let d = compareFloat(
        recordType,
        recordID,
        "\(prefix).threshold.longitude",
        txt.threshold?.longitude,
        csv.threshold?.longitude
      ) {
        discrepancies.append(d)
      }
      if let d = compareFloat(
        recordType,
        recordID,
        "\(prefix).threshold.elevation",
        txt.threshold?.elevation,
        csv.threshold?.elevation,
        tolerance: 1.0
      ) {
        discrepancies.append(d)
      }
    }

    if let d = compareUInt(
      recordType,
      recordID,
      "\(prefix).thresholdCrossingHeight",
      txt.thresholdCrossingHeight,
      csv.thresholdCrossingHeight
    ) {
      discrepancies.append(d)
    }
    if let d = compareFloat(
      recordType,
      recordID,
      "\(prefix).visualGlidepath",
      txt.visualGlidepath,
      csv.visualGlidepath,
      tolerance: 0.1
    ) {
      discrepancies.append(d)
    }

    // Displaced threshold
    if txt.displacedThreshold != nil || csv.displacedThreshold != nil {
      if let d = compareFloat(
        recordType,
        recordID,
        "\(prefix).displacedThreshold.latitude",
        txt.displacedThreshold?.latitude,
        csv.displacedThreshold?.latitude
      ) {
        discrepancies.append(d)
      }
      if let d = compareFloat(
        recordType,
        recordID,
        "\(prefix).displacedThreshold.longitude",
        txt.displacedThreshold?.longitude,
        csv.displacedThreshold?.longitude
      ) {
        discrepancies.append(d)
      }
      if let d = compareFloat(
        recordType,
        recordID,
        "\(prefix).displacedThreshold.elevation",
        txt.displacedThreshold?.elevation,
        csv.displacedThreshold?.elevation,
        tolerance: 1.0
      ) {
        discrepancies.append(d)
      }
    }

    if let d = compareUInt(
      recordType,
      recordID,
      "\(prefix).thresholdDisplacement",
      txt.thresholdDisplacement,
      csv.thresholdDisplacement
    ) {
      discrepancies.append(d)
    }
    if let d = compareFloat(
      recordType,
      recordID,
      "\(prefix).touchdownZoneElevation",
      txt.touchdownZoneElevation,
      csv.touchdownZoneElevation,
      tolerance: 1.0
    ) {
      discrepancies.append(d)
    }
    if let d = compareFloat(
      recordType,
      recordID,
      "\(prefix).gradient",
      txt.gradient,
      csv.gradient,
      tolerance: 0.01
    ) {
      discrepancies.append(d)
    }

    // Declared distances
    if let d = compareUInt(recordType, recordID, "\(prefix).TORA", txt.TORA, csv.TORA) {
      discrepancies.append(d)
    }
    if let d = compareUInt(recordType, recordID, "\(prefix).TODA", txt.TODA, csv.TODA) {
      discrepancies.append(d)
    }
    if let d = compareUInt(recordType, recordID, "\(prefix).ASDA", txt.ASDA, csv.ASDA) {
      discrepancies.append(d)
    }
    if let d = compareUInt(recordType, recordID, "\(prefix).LDA", txt.LDA, csv.LDA) {
      discrepancies.append(d)
    }

    // Visual glideslope indicator
    discrepancies.append(
      contentsOf: compareVGSI(
        recordType,
        recordID,
        "\(prefix).visualGlideslopeIndicator",
        txt.visualGlideslopeIndicator,
        csv.visualGlideslopeIndicator
      )
    )

    // RVR Sensors
    let txtRVR = txt.RVRSensors.map(\.rawValue).sorted().joined(separator: ",")
    let csvRVR = csv.RVRSensors.map(\.rawValue).sorted().joined(separator: ",")
    if txtRVR != csvRVR {
      discrepancies.append(
        FieldDiscrepancy(
          recordType: recordType,
          recordID: recordID,
          field: "\(prefix).RVRSensors",
          txtValue: txtRVR.isEmpty ? "nil" : txtRVR,
          csvValue: csvRVR.isEmpty ? "nil" : csvRVR
        )
      )
    }

    if let d = compareBool(recordType, recordID, "\(prefix).hasRVV", txt.hasRVV, csv.hasRVV) {
      discrepancies.append(d)
    }

    // Lighting
    if let d = compareEnum(
      recordType,
      recordID,
      "\(prefix).approachLighting",
      txt.approachLighting,
      csv.approachLighting
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(recordType, recordID, "\(prefix).hasREIL", txt.hasREIL, csv.hasREIL) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      recordType,
      recordID,
      "\(prefix).hasCenterlineLighting",
      txt.hasCenterlineLighting,
      csv.hasCenterlineLighting
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      recordType,
      recordID,
      "\(prefix).endTouchdownLighting",
      txt.endTouchdownLighting,
      csv.endTouchdownLighting
    ) {
      discrepancies.append(d)
    }

    // Controlling object
    discrepancies.append(
      contentsOf: compareControllingObject(
        recordType,
        recordID,
        "\(prefix).controllingObject",
        txt.controllingObject,
        csv.controllingObject
      )
    )

    // Source information
    if let d = compareString(
      recordType,
      recordID,
      "\(prefix).positionSource",
      txt.positionSource,
      csv.positionSource
    ) {
      discrepancies.append(d)
    }
    if let d = compareDate(
      recordType,
      recordID,
      "\(prefix).positionSourceDate",
      txt.positionSourceDate,
      csv.positionSourceDate
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(
      recordType,
      recordID,
      "\(prefix).elevationSource",
      txt.elevationSource,
      csv.elevationSource
    ) {
      discrepancies.append(d)
    }
    if let d = compareDate(
      recordType,
      recordID,
      "\(prefix).elevationSourceDate",
      txt.elevationSourceDate,
      csv.elevationSourceDate
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(
      recordType,
      recordID,
      "\(prefix).touchdownZoneElevationSource",
      txt.touchdownZoneElevationSource,
      csv.touchdownZoneElevationSource
    ) {
      discrepancies.append(d)
    }
    if let d = compareDate(
      recordType,
      recordID,
      "\(prefix).touchdownZoneElevationSourceDate",
      txt.touchdownZoneElevationSourceDate,
      csv.touchdownZoneElevationSourceDate
    ) {
      discrepancies.append(d)
    }

    // Arresting systems
    let txtArresting = txt.arrestingSystems.sorted().joined(separator: ",")
    let csvArresting = csv.arrestingSystems.sorted().joined(separator: ",")
    if txtArresting != csvArresting {
      discrepancies.append(
        FieldDiscrepancy(
          recordType: recordType,
          recordID: recordID,
          field: "\(prefix).arrestingSystems",
          txtValue: txtArresting.isEmpty ? "nil" : txtArresting,
          csvValue: csvArresting.isEmpty ? "nil" : csvArresting
        )
      )
    }

    // LAHSO
    discrepancies.append(
      contentsOf: compareLAHSO(recordType, recordID, "\(prefix).LAHSO", txt.LAHSO, csv.LAHSO)
    )

    return discrepancies
  }

  private func compareVGSI(
    _ recordType: String,
    _ recordID: String,
    _ prefix: String,
    _ txt: RunwayEnd.VisualGlideslopeIndicator?,
    _ csv: RunwayEnd.VisualGlideslopeIndicator?
  ) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []

    if txt != nil || csv != nil {
      if let txtVGSI = txt, let csvVGSI = csv {
        if txtVGSI.type.rawValue != csvVGSI.type.rawValue {
          discrepancies.append(
            FieldDiscrepancy(
              recordType: recordType,
              recordID: recordID,
              field: "\(prefix).type",
              txtValue: txtVGSI.type.rawValue,
              csvValue: csvVGSI.type.rawValue
            )
          )
        }
        if let d = compareUInt(
          recordType,
          recordID,
          "\(prefix).number",
          txtVGSI.number,
          csvVGSI.number
        ) {
          discrepancies.append(d)
        }
        if let d = compareEnum(
          recordType,
          recordID,
          "\(prefix).side",
          txtVGSI.side,
          csvVGSI.side
        ) {
          discrepancies.append(d)
        }
      } else {
        discrepancies.append(
          FieldDiscrepancy(
            recordType: recordType,
            recordID: recordID,
            field: "\(prefix).present",
            txtValue: txt != nil ? "present" : "nil",
            csvValue: csv != nil ? "present" : "nil"
          )
        )
      }
    }

    return discrepancies
  }

  private func compareControllingObject(
    _ recordType: String,
    _ recordID: String,
    _ prefix: String,
    _ txt: RunwayEnd.ControllingObject?,
    _ csv: RunwayEnd.ControllingObject?
  ) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []

    if txt != nil || csv != nil {
      if let txtObj = txt, let csvObj = csv {
        if txtObj.category.rawValue != csvObj.category.rawValue {
          discrepancies.append(
            FieldDiscrepancy(
              recordType: recordType,
              recordID: recordID,
              field: "\(prefix).category",
              txtValue: txtObj.category.rawValue,
              csvValue: csvObj.category.rawValue
            )
          )
        }
        if let d = compareString(
          recordType,
          recordID,
          "\(prefix).runwayCategory",
          txtObj.runwayCategory,
          csvObj.runwayCategory
        ) {
          discrepancies.append(d)
        }
        if let d = compareUInt(
          recordType,
          recordID,
          "\(prefix).clearanceSlope",
          txtObj.clearanceSlope,
          csvObj.clearanceSlope
        ) {
          discrepancies.append(d)
        }
        if let d = compareUInt(
          recordType,
          recordID,
          "\(prefix).heightAboveRunway",
          txtObj.heightAboveRunway,
          csvObj.heightAboveRunway
        ) {
          discrepancies.append(d)
        }
        if let d = compareUInt(
          recordType,
          recordID,
          "\(prefix).distanceFromRunway",
          txtObj.distanceFromRunway,
          csvObj.distanceFromRunway
        ) {
          discrepancies.append(d)
        }
        // Compare offset
        if txtObj.offsetFromCenterline != nil || csvObj.offsetFromCenterline != nil {
          let txtOffset =
            txtObj.offsetFromCenterline.map {
              "\($0.distance)\($0.direction.rawValue)"
            } ?? "nil"
          let csvOffset =
            csvObj.offsetFromCenterline.map {
              "\($0.distance)\($0.direction.rawValue)"
            } ?? "nil"
          if txtOffset != csvOffset {
            discrepancies.append(
              FieldDiscrepancy(
                recordType: recordType,
                recordID: recordID,
                field: "\(prefix).offsetFromCenterline",
                txtValue: txtOffset,
                csvValue: csvOffset
              )
            )
          }
        }
      } else {
        discrepancies.append(
          FieldDiscrepancy(
            recordType: recordType,
            recordID: recordID,
            field: "\(prefix).present",
            txtValue: txt != nil ? "present" : "nil",
            csvValue: csv != nil ? "present" : "nil"
          )
        )
      }
    }

    return discrepancies
  }

  private func compareLAHSO(
    _ recordType: String,
    _ recordID: String,
    _ prefix: String,
    _ txt: RunwayEnd.LAHSOPoint?,
    _ csv: RunwayEnd.LAHSOPoint?
  ) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []

    if txt != nil || csv != nil {
      if let txtLAHSO = txt, let csvLAHSO = csv {
        if let d = compareUInt(
          recordType,
          recordID,
          "\(prefix).availableDistance",
          txtLAHSO.availableDistance,
          csvLAHSO.availableDistance
        ) {
          discrepancies.append(d)
        }
        if let d = compareString(
          recordType,
          recordID,
          "\(prefix).intersectingRunwayID",
          txtLAHSO.intersectingRunwayID,
          csvLAHSO.intersectingRunwayID
        ) {
          discrepancies.append(d)
        }
        if let d = compareString(
          recordType,
          recordID,
          "\(prefix).definingEntity",
          txtLAHSO.definingEntity,
          csvLAHSO.definingEntity
        ) {
          discrepancies.append(d)
        }
        if txtLAHSO.position != nil || csvLAHSO.position != nil {
          if let d = compareFloat(
            recordType,
            recordID,
            "\(prefix).position.latitude",
            txtLAHSO.position?.latitude,
            csvLAHSO.position?.latitude
          ) {
            discrepancies.append(d)
          }
          if let d = compareFloat(
            recordType,
            recordID,
            "\(prefix).position.longitude",
            txtLAHSO.position?.longitude,
            csvLAHSO.position?.longitude
          ) {
            discrepancies.append(d)
          }
        }
        if let d = compareString(
          recordType,
          recordID,
          "\(prefix).positionSource",
          txtLAHSO.positionSource,
          csvLAHSO.positionSource
        ) {
          discrepancies.append(d)
        }
        if let d = compareDate(
          recordType,
          recordID,
          "\(prefix).positionSourceDate",
          txtLAHSO.positionSourceDate,
          csvLAHSO.positionSourceDate
        ) {
          discrepancies.append(d)
        }
      } else {
        discrepancies.append(
          FieldDiscrepancy(
            recordType: recordType,
            recordID: recordID,
            field: "\(prefix).present",
            txtValue: txt != nil ? "present" : "nil",
            csvValue: csv != nil ? "present" : "nil"
          )
        )
      }
    }

    return discrepancies
  }

  private func compareNavaidFields(txt: Navaid, csv: Navaid) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []
    let rt = "Navaid"
    let id = "\(txt.ID) (\(txt.type.rawValue))"

    // Basic identifiers
    if let d = compareString(rt, id, "name", txt.name, csv.name) { discrepancies.append(d) }
    if let d = compareEnum(rt, id, "type", txt.type, csv.type) { discrepancies.append(d) }
    if let d = compareString(rt, id, "city", txt.city, csv.city) { discrepancies.append(d) }
    if let d = compareString(rt, id, "stateName", txt.stateName, csv.stateName) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "FAARegion", txt.FAARegion, csv.FAARegion) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "country", txt.country, csv.country) {
      discrepancies.append(d)
    }

    // Ownership
    if let d = compareString(rt, id, "ownerName", txt.ownerName, csv.ownerName) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "operatorName", txt.operatorName, csv.operatorName) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      rt,
      id,
      "commonSystemUsage",
      txt.commonSystemUsage,
      csv.commonSystemUsage
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "publicUse", txt.publicUse, csv.publicUse) {
      discrepancies.append(d)
    }

    // Operations
    if let d = compareString(rt, id, "hoursOfOperation", txt.hoursOfOperation, csv.hoursOfOperation)
    {
      discrepancies.append(d)
    }
    if let d = compareString(
      rt,
      id,
      "highAltitudeARTCCCode",
      txt.highAltitudeARTCCCode,
      csv.highAltitudeARTCCCode
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(
      rt,
      id,
      "lowAltitudeARTCCCode",
      txt.lowAltitudeARTCCCode,
      csv.lowAltitudeARTCCCode
    ) {
      discrepancies.append(d)
    }

    // Position
    if let d = compareFloat(rt, id, "latitude", txt.position.latitude, csv.position.latitude) {
      discrepancies.append(d)
    }
    if let d = compareFloat(rt, id, "longitude", txt.position.longitude, csv.position.longitude) {
      discrepancies.append(d)
    }
    if let d = compareFloat(
      rt,
      id,
      "elevation",
      txt.position.elevation,
      csv.position.elevation,
      tolerance: 1.0
    ) {
      discrepancies.append(d)
    }

    // TACAN position (if present)
    if txt.TACANPosition != nil || csv.TACANPosition != nil {
      if let d = compareFloat(
        rt,
        id,
        "TACANLatitude",
        txt.TACANPosition?.latitude,
        csv.TACANPosition?.latitude
      ) {
        discrepancies.append(d)
      }
      if let d = compareFloat(
        rt,
        id,
        "TACANLongitude",
        txt.TACANPosition?.longitude,
        csv.TACANPosition?.longitude
      ) {
        discrepancies.append(d)
      }
    }

    // Magnetic variation
    if let d = compareInt(rt, id, "magneticVariation", txt.magneticVariation, csv.magneticVariation)
    {
      discrepancies.append(d)
    }
    if let d = compareDate(
      rt,
      id,
      "magneticVariationEpoch",
      txt.magneticVariationEpoch,
      csv.magneticVariationEpoch
    ) {
      discrepancies.append(d)
    }

    // Transmitter characteristics
    if let d = compareBool(
      rt,
      id,
      "simultaneousVoice",
      txt.simultaneousVoice,
      csv.simultaneousVoice
    ) {
      discrepancies.append(d)
    }
    if let d = compareUInt(rt, id, "powerOutput", txt.powerOutput, csv.powerOutput) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "automaticVoiceID", txt.automaticVoiceID, csv.automaticVoiceID) {
      discrepancies.append(d)
    }
    if let d = compareEnum(
      rt,
      id,
      "monitoringCategory",
      txt.monitoringCategory,
      csv.monitoringCategory
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "radioVoiceCall", txt.radioVoiceCall, csv.radioVoiceCall) {
      discrepancies.append(d)
    }

    // Frequency/Channel
    if let d = compareUInt(rt, id, "frequency", txt.frequency, csv.frequency) {
      discrepancies.append(d)
    }
    // Compare TACAN channel
    if txt.TACANChannel?.channel != csv.TACANChannel?.channel
      || txt.TACANChannel?.band != csv.TACANChannel?.band
    {
      let txtChannel = txt.TACANChannel.map { "\($0.channel)\($0.band.rawValue)" } ?? "nil"
      let csvChannel = csv.TACANChannel.map { "\($0.channel)\($0.band.rawValue)" } ?? "nil"
      if txtChannel != csvChannel {
        discrepancies.append(
          FieldDiscrepancy(
            recordType: rt,
            recordID: id,
            field: "TACANChannel",
            txtValue: txtChannel,
            csvValue: csvChannel
          )
        )
      }
    }

    // Beacon/Fan marker
    if let d = compareString(rt, id, "beaconIdentifier", txt.beaconIdentifier, csv.beaconIdentifier)
    {
      discrepancies.append(d)
    }
    if let d = compareEnum(rt, id, "fanMarkerType", txt.fanMarkerType, csv.fanMarkerType) {
      discrepancies.append(d)
    }
    if let d = compareUInt(
      rt,
      id,
      "fanMarkerMajorBearing",
      txt.fanMarkerMajorBearing,
      csv.fanMarkerMajorBearing
    ) {
      discrepancies.append(d)
    }

    // Service volumes
    if let d = compareEnum(rt, id, "VORServiceVolume", txt.VORServiceVolume, csv.VORServiceVolume) {
      discrepancies.append(d)
    }
    if let d = compareEnum(rt, id, "DMEServiceVolume", txt.DMEServiceVolume, csv.DMEServiceVolume) {
      discrepancies.append(d)
    }

    // Flags
    if let d = compareBool(
      rt,
      id,
      "lowAltitudeInHighStructure",
      txt.lowAltitudeInHighStructure,
      csv.lowAltitudeInHighStructure
    ) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "ZMarkerAvailable", txt.ZMarkerAvailable, csv.ZMarkerAvailable) {
      discrepancies.append(d)
    }

    // TWEB
    if let d = compareString(rt, id, "TWEBHours", txt.TWEBHours, csv.TWEBHours) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "TWEBPhone", txt.TWEBPhone, csv.TWEBPhone) {
      discrepancies.append(d)
    }

    // FSS/NOTAM
    if let d = compareString(
      rt,
      id,
      "controllingFSSCode",
      txt.controllingFSSCode,
      csv.controllingFSSCode
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(
      rt,
      id,
      "NOTAMAccountabilityCode",
      txt.NOTAMAccountabilityCode,
      csv.NOTAMAccountabilityCode
    ) {
      discrepancies.append(d)
    }

    // Status and flags
    if let d = compareEnum(rt, id, "status", txt.status, csv.status) { discrepancies.append(d) }
    if let d = compareBool(rt, id, "pitchFlag", txt.pitchFlag, csv.pitchFlag) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "catchFlag", txt.catchFlag, csv.catchFlag) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "SUAFlag", txt.SUAFlag, csv.SUAFlag) { discrepancies.append(d) }
    if let d = compareBool(rt, id, "restrictionFlag", txt.restrictionFlag, csv.restrictionFlag) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "HIWASFlag", txt.HIWASFlag, csv.HIWASFlag) {
      discrepancies.append(d)
    }
    if let d = compareBool(
      rt,
      id,
      "TWEBRestrictionFlag",
      txt.TWEBRestrictionFlag,
      csv.TWEBRestrictionFlag
    ) {
      discrepancies.append(d)
    }

    return discrepancies
  }

  private func compareFSSFields(txt: FSS, csv: FSS) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []
    let rt = "FSS"
    let id = txt.ID

    // Identifiers
    if let d = compareString(rt, id, "name", txt.name, csv.name) { discrepancies.append(d) }
    if let d = compareString(rt, id, "radioIdentifier", txt.radioIdentifier, csv.radioIdentifier) {
      discrepancies.append(d)
    }

    // Basic info
    if let d = compareEnum(rt, id, "type", txt.type, csv.type) { discrepancies.append(d) }
    if let d = compareString(rt, id, "hoursOfOperation", txt.hoursOfOperation, csv.hoursOfOperation)
    {
      discrepancies.append(d)
    }
    if let d = compareEnum(rt, id, "status", txt.status, csv.status) { discrepancies.append(d) }
    if let d = compareString(
      rt,
      id,
      "lowAltEnrouteChartNumber",
      txt.lowAltEnrouteChartNumber,
      csv.lowAltEnrouteChartNumber
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "phoneNumber", txt.phoneNumber, csv.phoneNumber) {
      discrepancies.append(d)
    }

    // Operator
    if let d = compareEnum(rt, id, "owner", txt.owner, csv.owner) { discrepancies.append(d) }
    if let d = compareString(rt, id, "ownerName", txt.ownerName, csv.ownerName) {
      discrepancies.append(d)
    }
    if let d = compareEnum(rt, id, "operator", txt.operator, csv.operator) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "operatorName", txt.operatorName, csv.operatorName) {
      discrepancies.append(d)
    }

    // Capabilities
    if let d = compareBool(rt, id, "hasWeatherRadar", txt.hasWeatherRadar, csv.hasWeatherRadar) {
      discrepancies.append(d)
    }
    if let d = compareBool(rt, id, "hasEFAS", txt.hasEFAS, csv.hasEFAS) { discrepancies.append(d) }
    if let d = compareString(
      rt,
      id,
      "flightWatchAvailability",
      txt.flightWatchAvailability,
      csv.flightWatchAvailability
    ) {
      discrepancies.append(d)
    }
    if let d = compareString(
      rt,
      id,
      "nearestFSSIDWithTeletype",
      txt.nearestFSSIDWithTeletype,
      csv.nearestFSSIDWithTeletype
    ) {
      discrepancies.append(d)
    }

    // Location
    if let d = compareString(rt, id, "airportID", txt.airportID, csv.airportID) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "city", txt.city, csv.city) { discrepancies.append(d) }
    if let d = compareString(rt, id, "stateName", txt.stateName, csv.stateName) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "region", txt.region, csv.region) { discrepancies.append(d) }

    // Location coordinates
    if txt.location != nil || csv.location != nil {
      if let d = compareFloat(rt, id, "latitude", txt.location?.latitude, csv.location?.latitude) {
        discrepancies.append(d)
      }
      if let d = compareFloat(rt, id, "longitude", txt.location?.longitude, csv.location?.longitude)
      {
        discrepancies.append(d)
      }
    }

    return discrepancies
  }

  private func compareARTCCFields(txt: ARTCC, csv: ARTCC) -> [FieldDiscrepancy] {
    var discrepancies: [FieldDiscrepancy] = []
    let rt = "ARTCC"
    let id = txt.id

    // Identifiers
    if let d = compareString(rt, id, "ID", txt.ID, csv.ID) { discrepancies.append(d) }
    if let d = compareString(rt, id, "ICAOID", txt.ICAOID, csv.ICAOID) { discrepancies.append(d) }
    if let d = compareEnum(rt, id, "type", txt.type, csv.type) { discrepancies.append(d) }

    // Names
    if let d = compareString(rt, id, "name", txt.name, csv.name) { discrepancies.append(d) }
    if let d = compareString(rt, id, "alternateName", txt.alternateName, csv.alternateName) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "locationName", txt.locationName, csv.locationName) {
      discrepancies.append(d)
    }
    if let d = compareString(rt, id, "stateCode", txt.stateCode, csv.stateCode) {
      discrepancies.append(d)
    }

    // Location coordinates
    if txt.location != nil || csv.location != nil {
      if let d = compareFloat(rt, id, "latitude", txt.location?.latitude, csv.location?.latitude) {
        discrepancies.append(d)
      }
      if let d = compareFloat(rt, id, "longitude", txt.location?.longitude, csv.location?.longitude)
      {
        discrepancies.append(d)
      }
      if let d = compareFloat(
        rt,
        id,
        "elevation",
        txt.location?.elevation,
        csv.location?.elevation,
        tolerance: 1.0
      ) {
        discrepancies.append(d)
      }
    }

    return discrepancies
  }

  private func displayFieldDiscrepancySummary(_ discrepancies: [FieldDiscrepancy]) {
    guard !discrepancies.isEmpty else {
      print("\n✅ No field discrepancies found in sampled records!")
      return
    }

    print("\n" + String(repeating: "=", count: 80))
    print("FIELD DISCREPANCY SUMMARY")
    print(String(repeating: "=", count: 80))

    // Group discrepancies by record type and field
    var fieldCounts: [String: [String: Int]] = [:]

    for disc in discrepancies {
      if fieldCounts[disc.recordType] == nil {
        fieldCounts[disc.recordType] = [:]
      }
      fieldCounts[disc.recordType]![disc.field, default: 0] += 1
    }

    // Display summary by record type
    for (recordType, fields) in fieldCounts.sorted(by: { $0.key < $1.key }) {
      print("\n\(recordType) Fields with Discrepancies:")
      print("-" + String(repeating: "-", count: 40))

      // Sort fields by count of discrepancies (descending)
      let sortedFields = fields.sorted { $0.value > $1.value }

      for (field, count) in sortedFields {
        let percentage =
          Double(count) * 100.0 / Double(discrepancies.filter { $0.recordType == recordType }.count)
        let paddedField = field.padding(toLength: 25, withPad: " ", startingAt: 0)
        print(
          "  \(paddedField): \(String(format: "%3d", count)) occurrences (\(String(format: "%.1f", percentage))%)"
        )
      }
    }

    // Display overall statistics
    print("\n" + String(repeating: "-", count: 80))
    print("Total Field Discrepancies: \(discrepancies.count)")

    // Show most common fields with issues across all record types
    var overallFieldCounts: [String: Int] = [:]
    for disc in discrepancies {
      let key = "\(disc.recordType).\(disc.field)"
      overallFieldCounts[key, default: 0] += 1
    }

    let topFields = overallFieldCounts.sorted { $0.value > $1.value }.prefix(10)
    if !topFields.isEmpty {
      print("\nTop 10 Fields with Most Discrepancies:")
      for (field, count) in topFields {
        let paddedField = field.padding(toLength: 35, withPad: " ", startingAt: 0)
        print("  \(paddedField): \(String(format: "%3d", count))")
      }
    }
  }
}

// MARK: - Data Models

struct ParseResults {
  var airports: [Airport] = []
  var airportCount: Int = 0

  var navaids: [NavaidKey: Navaid] = [:]
  var navaidCount: Int = 0

  var fssStations: [String: FSS] = [:]
  var fssCount: Int = 0

  var artccFacilities: [ARTCCKey: ARTCC] = [:]
  var artccCount: Int = 0
}

struct DetailedComparisonResult {
  var airportsMissingInCSV: Set<String> = []
  var airportsMissingInTXT: Set<String> = []
  var navaidsMissingInCSV: Set<NavaidKey> = []
  var navaidsMissingInTXT: Set<NavaidKey> = []
  var fssMissingInCSV: Set<String> = []
  var fssMissingInTXT: Set<String> = []
  var artccMissingInCSV: Set<ARTCCKey> = []
  var artccMissingInTXT: Set<ARTCCKey> = []
  var fieldDiscrepancies: [FieldDiscrepancy] = []
}

struct FieldDiscrepancy: Codable {
  let recordType: String
  let recordID: String
  let field: String
  let txtValue: String
  let csvValue: String
}

struct EnhancedComparisonReport: Codable {
  let timestamp: Date
  let txtAirportCount: Int
  let csvAirportCount: Int
  let airportsMissingInCSV: Int
  let airportsMissingInTXT: Int
  let txtNavaidCount: Int
  let csvNavaidCount: Int
  let navaidsMissingInCSV: Int
  let navaidsMissingInTXT: Int
  let txtFSSCount: Int
  let csvFSSCount: Int
  let fssMissingInCSV: Int
  let fssMissingInTXT: Int
  let txtARTCCCount: Int
  let csvARTCCCount: Int
  let artccMissingInCSV: Int
  let artccMissingInTXT: Int
  let fieldDiscrepancies: [FieldDiscrepancy]
}
