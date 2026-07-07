import Foundation
import Testing

@testable import SwiftNASR

@Suite
struct RecordParseErrorTests {
  @Test
  func carriesFieldErrorContextAndADescription() {
    let underlying = ParserError.unknownRecordEnumValue("ZZ")
    let error = RecordParseError.fieldError(
      recordType: .navaids,
      recordID: "OAK",
      field: "fanMarkerType",
      value: "ZZ",
      underlying: underlying
    )

    guard case let .fieldError(type, id, field, value, _) = error else {
      Issue.record("expected .fieldError")
      return
    }
    #expect(type == .navaids)
    #expect(id == "OAK")
    #expect(field == "fanMarkerType")
    #expect(value == "ZZ")
    #expect(error.errorDescription != nil)
  }

  @Test
  func wrapsAnArbitraryThrownErrorAsARecordError() {
    let error = RecordParseError.fromThrown(
      recordType: .airports,
      recordID: nil,
      ParserError.missingRequiredField(field: "id", recordType: "APT")
    )

    guard case let .recordError(type, id, _) = error else {
      Issue.record("expected .recordError")
      return
    }
    #expect(type == .airports)
    #expect(id == nil)
  }
}
