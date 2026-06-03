import Foundation
import Nimble
import Quick

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

final class DiagnosingParserSpec: AsyncSpec {
  override static func spec() {
    describe("diagnose") {
      it("returns the value and records nothing for a known raw value") {
        let parser = TestDiagnosingParser()
        let value = await parser.decode("R")
        expect(value).to(equal(.red))
        let pending = await parser.takeDiagnostics()
        expect(pending).to(beEmpty())
      }

      it("returns nil and records nothing for a blank/absent value") {
        let parser = TestDiagnosingParser()
        let value = await parser.decode("")
        expect(value).to(beNil())
        let pending = await parser.takeDiagnostics()
        expect(pending).to(beEmpty())
      }

      it("returns nil and records a field error for an unknown non-blank value") {
        let parser = TestDiagnosingParser()
        let value = await parser.decode("ZZ")
        expect(value).to(beNil())
        let pending = await parser.takeDiagnostics()
        expect(pending).to(haveCount(1))
        guard case let .fieldError(_, id, field, raw, _) = pending[0] else {
          fail("expected .fieldError"); return
        }
        expect(id).to(equal("REC1"))
        expect(field).to(equal("color"))
        expect(raw).to(equal("ZZ"))
      }

      it("clears pending diagnostics when drained") {
        let parser = TestDiagnosingParser()
        _ = await parser.decode("ZZ")
        _ = await parser.takeDiagnostics()
        let second = await parser.takeDiagnostics()
        expect(second).to(beEmpty())
      }
    }
  }
}
