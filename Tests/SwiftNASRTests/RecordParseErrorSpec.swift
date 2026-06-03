import Foundation
import Nimble
import Quick

@testable import SwiftNASR

final class RecordParseErrorSpec: QuickSpec {
  override static func spec() {
    describe("RecordParseError") {
      it("carries field-error context and a description") {
        let underlying = ParserError.unknownRecordEnumValue("ZZ")
        let error = RecordParseError.fieldError(
          recordType: .navaids,
          recordID: "OAK",
          field: "fanMarkerType",
          value: "ZZ",
          underlying: underlying
        )

        guard case let .fieldError(type, id, field, value, _) = error else {
          fail("expected .fieldError"); return
        }
        expect(type).to(equal(.navaids))
        expect(id).to(equal("OAK"))
        expect(field).to(equal("fanMarkerType"))
        expect(value).to(equal("ZZ"))
        expect(error.errorDescription).toNot(beNil())
      }

      it("wraps an arbitrary thrown error as a record error") {
        let error = RecordParseError.fromThrown(
          recordType: .airports,
          recordID: nil,
          ParserError.missingRequiredField(field: "id", recordType: "APT")
        )

        guard case let .recordError(type, id, _) = error else {
          fail("expected .recordError"); return
        }
        expect(type).to(equal(.airports))
        expect(id).to(beNil())
      }
    }
  }
}
