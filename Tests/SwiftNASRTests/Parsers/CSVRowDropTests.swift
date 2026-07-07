import Foundation
import Testing

@testable import SwiftNASR

// A CSV parser test-double that processes rows and throws on a sentinel value.
private actor RowCountingParser: CSVParser, DiagnosingParser {
  static let type = RecordType.navaids
  var distribution: (any Distribution)?
  let CSVFiles = ["TEST.csv"]
  var progress: Progress?
  var bytesRead: Int64 = 0
  var pendingDiagnostics = [RecordParseError]()
  var kept = [String]()

  func prepare(distribution: Distribution) throws { self.distribution = distribution }
  func finish(data _: NASRData) {}

  func parse(data _: Data) async throws {
    try await parseCSVFile(filename: "TEST.csv", requiredColumns: ["ID"]) { row in
      let id: String = try row["ID"]
      if id == "BAD" { throw ParserError.badData("poison row") }
      self.kept.append(id)
    }
  }
}

@Suite
struct CSVRowDropTests {
  @Test
  func keepsEveryGoodRowWhenOneRowThrows() async throws {
    let tempdir = FileManager.default.temporaryDirectory.appendingPathComponent(
      ProcessInfo.processInfo.globallyUniqueString
    )
    try FileManager.default.createDirectory(at: tempdir, withIntermediateDirectories: true)
    let csv = "ID\r\nA\r\nBAD\r\nB\r\nC\r\n"
    try Data(csv.utf8).write(to: tempdir.appendingPathComponent("TEST.csv"))
    defer { try? FileManager.default.removeItem(at: tempdir) }

    let parser = RowCountingParser()
    let distribution = DirectoryDistribution(location: tempdir, format: .csv)
    try await parser.prepare(distribution: distribution)
    try await parser.parse(data: Data("CSV".utf8))

    let kept = await parser.kept
    #expect(kept == ["A", "B", "C"])  // not just ["A"]
    let diagnostics = await parser.takeDiagnostics()
    #expect(diagnostics.count == 1)
    guard case .recordError = diagnostics[0] else {
      Issue.record("expected .recordError")
      return
    }
  }
}
