import Foundation
import Testing

@testable import SwiftNASR

enum TestEnum: String, RecordEnum {
  case first = "1"
  case second = "2"

  static let synonyms: [RawValue: Self] = [
    "ONE": .first,
    "TWO": .second
  ]
}

@Suite
struct RecordEnumTests {
  @Test
  func returnsAnEnumValueByRawValue() {
    #expect(TestEnum.for("1") == .first)
  }

  @Test
  func returnsAnEnumValueBySynonym() {
    #expect(TestEnum.for("ONE") == .first)
  }

  @Test
  func returnsNilForUnknownValues() {
    #expect(TestEnum.for("3") == nil)
  }
}
