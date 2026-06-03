import Foundation
import Nimble
import Quick

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

final class CSVRowDropSpec: AsyncSpec {
  override static func spec() {
    it("keeps every good row when one row throws") {
      let tempdir = FileManager.default.temporaryDirectory.appendingPathComponent(
        ProcessInfo().globallyUniqueString
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
      expect(kept).to(equal(["A", "B", "C"]))  // not just ["A"]
      let diagnostics = await parser.takeDiagnostics()
      expect(diagnostics).to(haveCount(1))
      guard case .recordError = diagnostics[0] else { fail("expected .recordError"); return }
    }
  }
}
