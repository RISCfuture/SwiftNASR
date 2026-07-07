import Foundation
import Testing

@testable import SwiftNASR

@Suite
struct StringTests {
  @Test
  func partitionsByLength() {
    let partitions = "abc123def".partition(by: 3)
    #expect(partitions == ["abc", "123", "def"])
  }

  @Test
  func splitsOnACharacterSet() {
    let components = "abc 123\na".split(separator: .whitespacesAndNewlines)
    #expect(components == ["abc", "123", "a"])
  }

  @Test
  func dropsSeparatorCharactersAndOmitsEmptyTokensAtTheEdges() {
    // The runway-surface parsers rely on this for codes like "ASPH/GRVL".
    let set = CharacterSet(charactersIn: "-/")
    #expect("ASPH/GRVL".split(separator: set) == ["ASPH", "GRVL"])
    #expect("-ASPH".split(separator: set) == ["ASPH"])  // leading
    #expect("ASPH--CONC".split(separator: set) == ["ASPH", "CONC"])  // doubled
    #expect("ASPH-".split(separator: set) == ["ASPH"])  // trailing
    #expect("-".split(separator: set).isEmpty)  // separators only
  }
}
