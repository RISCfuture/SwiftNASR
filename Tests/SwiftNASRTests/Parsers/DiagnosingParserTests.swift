import Foundation
import Testing

@testable import SwiftNASR

// Minimal enum + parser to exercise the diagnose primitive in isolation.
private enum Color: String, RecordEnum { case red = "R", green = "G" }

private actor TestDiagnosingParser: DiagnosingParser {
  static let type = RecordType.navaids
  var pendingDiagnostics = [RecordParseError]()

  func prepare(distribution _: Distribution) throws {}
  func parse(data _: Data) throws {}
  func finish(data _: NASRData) {}

  func decode(_ raw: String?) -> Color? {
    diagnose(Color.self, raw, field: "color", id: "REC1")
  }
}

@Suite
struct DiagnosingParserTests {
  @Test
  func returnsTheValueAndRecordsNothingForAKnownRawValue() async {
    let parser = TestDiagnosingParser()
    let value = await parser.decode("R")
    #expect(value == .red)
    let pending = await parser.takeDiagnostics()
    #expect(pending.isEmpty)
  }

  @Test
  func returnsNilAndRecordsNothingForABlankOrAbsentValue() async {
    let parser = TestDiagnosingParser()
    let value = await parser.decode("")
    #expect(value == nil)
    let pending = await parser.takeDiagnostics()
    #expect(pending.isEmpty)
  }

  @Test
  func returnsNilAndRecordsAFieldErrorForAnUnknownNonBlankValue() async {
    let parser = TestDiagnosingParser()
    let value = await parser.decode("ZZ")
    #expect(value == nil)
    let pending = await parser.takeDiagnostics()
    #expect(pending.count == 1)
    guard case let .fieldError(_, id, field, raw, _) = pending[0] else {
      Issue.record("expected .fieldError")
      return
    }
    #expect(id == "REC1")
    #expect(field == "color")
    #expect(raw == "ZZ")
  }

  @Test
  func clearsPendingDiagnosticsWhenDrained() async {
    let parser = TestDiagnosingParser()
    _ = await parser.decode("ZZ")
    _ = await parser.takeDiagnostics()
    let second = await parser.takeDiagnostics()
    #expect(second.isEmpty)
  }
}
