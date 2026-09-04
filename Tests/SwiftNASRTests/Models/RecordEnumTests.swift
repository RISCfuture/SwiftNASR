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
  func `returns an enum value by raw value`() {
    #expect(TestEnum.for("1") == .first)
  }

  @Test
  func `returns an enum value by synonym`() {
    #expect(TestEnum.for("ONE") == .first)
  }

  @Test
  func `returns nil for unknown values`() {
    #expect(TestEnum.for("3") == nil)
  }
}
