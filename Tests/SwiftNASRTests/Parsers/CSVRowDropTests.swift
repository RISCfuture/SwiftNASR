import Foundation
import Synchronization
import Testing

@testable import SwiftNASR

// A CSV parser test-double that processes rows and throws on sentinel values.
private actor RowCountingParser: DiagnosingCSVParser {
  static let type = RecordType.navaids
  static let identityColumns = ["ID"]

  var distribution: (any Distribution)?
  let CSVFiles = ["TEST.csv"]
  var pendingDiagnostics = [RecordParseError]()
  var kept = [String]()

  func prepare(distribution: any Distribution) throws { self.distribution = distribution }
  func finish(data _: NASRData) {}

  func parse(data _: Data) async throws {
    try await parseCSVFile(filename: "TEST.csv", requiredColumns: ["ID"]) { row in
      let id: String = try row["ID"]
      if id == "BAD" { throw ParserError.badData("poison row") }
      if id == "CANCEL" { throw CancellationError() }
      self.kept.append(id)
    }
  }
}

/// A directory of CSV files, removed with the fixture.
private final class CSVDirectory {
  static let fixHeader =
    "EFF_DATE,FIX_ID,ICAO_REGION_CODE,STATE_CODE,COUNTRY_CODE,LAT_DECIMAL,LONG_DECIMAL,"
    + "FIX_ID_OLD,CHARTING_REMARK,FIX_USE_CODE,ARTCC_ID_HIGH,ARTCC_ID_LOW,PITCH_FLAG,"
    + "CATCH_FLAG,SUA_ATCAA_FLAG"

  let location = FileManager.default.temporaryDirectory.appendingPathComponent(
    ProcessInfo.processInfo.globallyUniqueString
  )

  var distribution: DirectoryDistribution { .init(location: location, format: .csv) }

  init(_ files: [String: [String]]) throws {
    try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
    for (name, lines) in files {
      let contents = lines.map { "\($0)\r\n" }.joined()
      try Data(contents.utf8).write(to: location.appendingPathComponent(name))
    }
  }

  func makeNASR() async -> NASR {
    let nasr = NASR(loader: NullLoader())
    await nasr.setDistribution(distribution)
    return nasr
  }

  /// Parses `type` through ``NASR/parse(_:progress:errorHandler:)``, proceeding
  /// past every error, and returns the parsed data with the reported errors.
  func parse(_ type: RecordType) async throws -> (NASRData, [RecordParseError]) {
    let nasr = await makeNASR()
    let errors = Mutex([RecordParseError]())
    try await nasr.parse(type) { error in
      errors.withLock { $0.append(error) }
      return .proceed
    }
    return (await nasr.data, errors.withLock { $0 })
  }

  func parseTestFile() async throws -> RowCountingParser {
    let parser = RowCountingParser()
    try await parser.prepare(distribution: distribution)
    try await parser.parse(data: Data("CSV".utf8))
    return parser
  }

  deinit { try? FileManager.default.removeItem(at: location) }
}

/// The location and identity of a dropped CSV row.
private struct DroppedRow: Equatable {
  let filename: String
  let rowNumber: UInt
  let recordID: String?
  let isTruncated: Bool

  init(filename: String, rowNumber: UInt, recordID: String?, isTruncated: Bool = false) {
    self.filename = filename
    self.rowNumber = rowNumber
    self.recordID = recordID
    self.isTruncated = isTruncated
  }

  init?(_ error: RecordParseError) {
    guard case let .recordError(_, recordID, underlying) = error,
      let rowError = underlying as? CSVRowError
    else { return nil }
    let isTruncated = if case .truncated = rowError.reason { true } else { false }
    self.init(
      filename: rowError.filename,
      rowNumber: rowError.rowNumber,
      recordID: recordID,
      isTruncated: isTruncated
    )
  }
}

@Suite
struct CSVRowDropTests {
  @Test
  func `keeps every good row when one row throws`() async throws {
    let directory = try CSVDirectory(["TEST.csv": ["ID", "A", "BAD", "B", "C"]])
    let parser = try await directory.parseTestFile()

    #expect(await parser.kept == ["A", "B", "C"])
    let diagnostics = await parser.takeDiagnostics()
    #expect(
      diagnostics.map(DroppedRow.init) == [
        .init(filename: "TEST.csv", rowNumber: 3, recordID: "BAD")
      ]
    )
  }

  @Test
  func `reports a truncated row and keeps the rows after it`() async throws {
    let directory = try CSVDirectory(["TEST.csv": ["ID,NAME", "A,Alpha", "T", "B,Bravo"]])
    let parser = try await directory.parseTestFile()

    #expect(await parser.kept == ["A", "B"])
    let diagnostics = await parser.takeDiagnostics()
    #expect(
      diagnostics.map(DroppedRow.init) == [
        .init(filename: "TEST.csv", rowNumber: 3, recordID: "T", isTruncated: true)
      ]
    )
  }

  @Test
  func `propagates cancellation instead of dropping the row`() async throws {
    let directory = try CSVDirectory(["TEST.csv": ["ID", "A", "CANCEL", "B"]])
    let parser = RowCountingParser()
    try await parser.prepare(distribution: directory.distribution)

    await #expect(throws: CancellationError.self) {
      try await parser.parse(data: Data("CSV".utf8))
    }
    #expect(await parser.kept == ["A"])
    #expect(await parser.takeDiagnostics().isEmpty)
  }

  @Test
  func `throws cancellation out of a parse whose task is cancelled`() async throws {
    let directory = try CSVDirectory([
      "FIX_BASE.csv": [
        CSVDirectory.fixHeader, "2026/10/29,ALPHA,K2,CA,US,37.5,-122.1,,,WP,ZOA,ZOA,N,N,N"
      ]
    ])
    let nasr = await directory.makeNASR()
    let errors = Mutex([RecordParseError]())

    let task = Task {
      while !Task.isCancelled { await Task.yield() }
      return try await nasr.parse(.reportingPoints) { error in
        errors.withLock { $0.append(error) }
        return .proceed
      }
    }
    task.cancel()

    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(errors.withLock { $0.isEmpty })
  }

  @Test
  func `recovers from a malformed fix and still reads its supplemental files`() async throws {
    let directory = try CSVDirectory([
      "FIX_BASE.csv": [
        CSVDirectory.fixHeader,
        "2026/10/29,ALPHA,K2,CA,US,37.5,-122.1,,,WP,ZOA,ZOA,N,N,N",
        "2026/10/29,BRAVO,K2,CA,US,north,-122.2,,,WP,ZOA,ZOA,N,N,N",
        "2026/10/29,DELTA,K2,CA,US,37.7,-122.3,,,WP,ZOA,ZOA,N,N,N"
      ],
      "FIX_NAV.csv": [
        "EFF_DATE,FIX_ID,ICAO_REGION_CODE,STATE_CODE,COUNTRY_CODE,NAV_ID,NAV_TYPE,BEARING,DISTANCE",
        "2026/10/29,ALPHA,K2,CA,US,OAK,VORTAC,90,10",
        "2026/10/29,DELTA,K2,CA,US,SFO,VOR/DME,180,20"
      ],
      "FIX_CHRT.csv": [
        "EFF_DATE,FIX_ID,ICAO_REGION_CODE,STATE_CODE,COUNTRY_CODE,CHARTING_TYPE_DESC",
        "2026/10/29,DELTA,K2,CA,US,IAP"
      ]
    ])

    let (data, errors) = try await directory.parse(.reportingPoints)

    #expect(
      errors.map(DroppedRow.init) == [
        .init(filename: "FIX_BASE.csv", rowNumber: 3, recordID: "BRAVO/K2")
      ]
    )
    let fixes = Dictionary(uniqueKeysWithValues: (await data.fixes ?? []).map { ($0.id, $0) })
    #expect(fixes.keys.sorted() == ["ALPHA", "DELTA"])
    #expect(fixes["ALPHA"]?.navaidMakeups.map(\.navaidId) == ["OAK"])
    #expect(fixes["DELTA"]?.navaidMakeups.map(\.navaidId) == ["SFO"])
    #expect(fixes["DELTA"]?.chartTypes == ["IAP"])
  }

  @Test
  func `reports dropped rows ahead of a missing supplemental file`() async throws {
    let directory = try CSVDirectory([
      "FIX_BASE.csv": [
        CSVDirectory.fixHeader,
        "2026/10/29,ALPHA,K2,CA,US,37.5,-122.1,,,WP,ZOA,ZOA,N,N,N",
        "2026/10/29,BRAVO,K2,CA,US,north,-122.2,,,WP,ZOA,ZOA,N,N,N"
      ]
    ])

    let (data, errors) = try await directory.parse(.reportingPoints)

    #expect(errors.count == 2)
    #expect(
      errors.first.flatMap(DroppedRow.init)
        == .init(filename: "FIX_BASE.csv", rowNumber: 3, recordID: "BRAVO/K2")
    )
    #expect(await data.fixes?.map(\.id) == ["ALPHA"])
  }

  @Test
  func `recovers from a malformed FSS and still reads its remarks`() async throws {
    let directory = try CSVDirectory([
      "FSS_BASE.csv": [
        "EFF_DATE,FSS_ID,NAME,FAC_STATUS",
        "2026/10/29,OAK,OAKLAND,A",
        "2026/10/29,BAD,BROKEN,Z",
        "2026/10/29,RNO,RENO,A"
      ],
      "FSS_RMK.csv": [
        "EFF_DATE,FSS_ID,REMARK",
        "2026/10/29,OAK,FIRST REMARK",
        "2026/10/29,RNO,SECOND REMARK"
      ]
    ])

    let (data, errors) = try await directory.parse(.flightServiceStations)

    #expect(
      errors.map(DroppedRow.init) == [
        .init(filename: "FSS_BASE.csv", rowNumber: 3, recordID: "BAD")
      ]
    )
    let FSSes = Dictionary(uniqueKeysWithValues: (await data.FSSes ?? []).map { ($0.id, $0) })
    #expect(FSSes.keys.sorted() == ["OAK", "RNO"])
    #expect(FSSes["OAK"]?.remarks == ["FIRST REMARK"])
    #expect(FSSes["RNO"]?.remarks == ["SECOND REMARK"])
  }

  @Test
  func `recovers from a malformed coded departure route`() async throws {
    let directory = try CSVDirectory([
      "CDR.csv": [
        "RCode,Orig,Dest,DepFix,Route String,DCNTR,ACNTR,TCNTRs,CoordReq,Play,NavEqp,Length",
        "SFOLAX01,KSFO,KLAX,SNTNA,KSFO SNTNA KLAX,ZOA,ZLA,,N,,,300",
        "SFOLAX02,KSFO,KLAX,SNTNA,KSFO SNTNA KLAX,ZOA,ZLA,,N,,,far",
        "SFOLAX03,KSFO,KLAX,SNTNA,KSFO SNTNA KLAX,ZOA,ZLA,,N,,,310"
      ]
    ])

    let (data, errors) = try await directory.parse(.codedDepartureRoutes)

    #expect(
      errors.map(DroppedRow.init) == [
        .init(filename: "CDR.csv", rowNumber: 3, recordID: "SFOLAX02")
      ]
    )
    let routeCodes = (await data.codedDepartureRoutes ?? []).map(\.routeCode).sorted()
    #expect(routeCodes == ["SFOLAX01", "SFOLAX03"])
  }
}
