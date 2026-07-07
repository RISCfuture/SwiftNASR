import Foundation
import Testing

@testable import SwiftNASR

@Suite
struct ByteParsingTests {
  private func bytes(_ string: String) -> ArraySlice<UInt8> {
    Array(string.utf8)[...]
  }

  // MARK: isBlank

  @Test
  func isBlankReturnsTrueForEmpty() {
    #expect(bytes("").isBlank())
  }

  @Test
  func isBlankReturnsTrueForSpacesOnly() {
    #expect(bytes("   ").isBlank())
  }

  @Test
  func isBlankReturnsTrueForTabsOnly() {
    #expect(bytes("\t\t").isBlank())
  }

  @Test
  func isBlankReturnsTrueForMixedWhitespace() {
    #expect(bytes(" \t ").isBlank())
  }

  @Test
  func isBlankReturnsFalseForNonWhitespace() {
    #expect(!bytes("abc").isBlank())
    #expect(!bytes(" abc ").isBlank())
  }

  // MARK: trimmed

  @Test
  func trimmedRemovesLeadingSpaces() {
    #expect(bytes("   abc").toTrimmedString() == "abc")
  }

  @Test
  func trimmedRemovesTrailingSpaces() {
    #expect(bytes("abc   ").toTrimmedString() == "abc")
  }

  @Test
  func trimmedRemovesLeadingAndTrailingSpaces() {
    #expect(bytes("   abc   ").toTrimmedString() == "abc")
  }

  @Test
  func trimmedRemovesTabs() {
    #expect(bytes("\tabc\t").toTrimmedString() == "abc")
  }

  @Test
  func trimmedRemovesMixedWhitespace() {
    #expect(bytes(" \t abc \t ").toTrimmedString() == "abc")
  }

  @Test
  func trimmedHandlesEmptyString() {
    #expect(bytes("").toTrimmedString()?.isEmpty == true)
  }

  @Test
  func trimmedHandlesWhitespaceOnly() {
    #expect(bytes("   ").toTrimmedString()?.isEmpty == true)
  }

  // MARK: parseInt

  @Test
  func parseIntParsesPositiveIntegers() {
    #expect(bytes("123").parseInt() == 123)
  }

  @Test
  func parseIntParsesNegativeIntegers() {
    #expect(bytes("-456").parseInt() == -456)
  }

  @Test
  func parseIntParsesWithLeadingPlus() {
    #expect(bytes("+789").parseInt() == 789)
  }

  @Test
  func parseIntTrimsWhitespace() {
    #expect(bytes("  123  ").parseInt() == 123)
  }

  @Test
  func parseIntReturnsNilForEmpty() {
    #expect(bytes("").parseInt() == nil)
  }

  @Test
  func parseIntReturnsNilForWhitespaceOnly() {
    #expect(bytes("   ").parseInt() == nil)
  }

  @Test
  func parseIntReturnsNilForNonNumeric() {
    #expect(bytes("abc").parseInt() == nil)
  }

  @Test
  func parseIntReturnsNilForMixedContent() {
    #expect(bytes("12a").parseInt() == nil)
  }

  // MARK: parseUInt

  @Test
  func parseUIntParsesUnsignedIntegers() {
    #expect(bytes("123").parseUInt() == 123)
  }

  @Test
  func parseUIntParsesWithLeadingPlus() {
    #expect(bytes("+789").parseUInt() == 789)
  }

  @Test
  func parseUIntTrimsWhitespace() {
    #expect(bytes("  456  ").parseUInt() == 456)
  }

  @Test
  func parseUIntReturnsNilForNegative() {
    #expect(bytes("-123").parseUInt() == nil)
  }

  // MARK: parseFloat

  @Test
  func parseFloatParsesFloats() throws {
    #expect(abs(try #require(bytes("123.45").parseFloat()) - 123.45) < 0.001)
  }

  @Test
  func parseFloatParsesNegativeFloats() throws {
    #expect(abs(try #require(bytes("-123.45").parseFloat()) - -123.45) < 0.001)
  }

  @Test
  func parseFloatTrimsWhitespace() throws {
    #expect(abs(try #require(bytes("  1.5  ").parseFloat()) - 1.5) < 0.001)
  }

  @Test
  func parseFloatReturnsNilForEmpty() {
    #expect(bytes("").parseFloat() == nil)
  }

  // MARK: parseFrequencyKHz

  @Test
  func parseFrequencyParsesMHzKHzFormat() {
    #expect(bytes("118.125").parseFrequencyKHz() == 118125)
  }

  @Test
  func parseFrequencyParsesMHzKFormatWithPadding() {
    #expect(bytes("118.1").parseFrequencyKHz() == 118100)
  }

  @Test
  func parseFrequencyParsesMHzOnlyFormat() {
    #expect(bytes("365").parseFrequencyKHz() == 365000)
  }

  @Test
  func parseFrequencyTrimsWhitespace() {
    #expect(bytes("  118.5  ").parseFrequencyKHz() == 118500)
  }

  @Test
  func parseFrequencyReturnsNilForInvalidFormat() {
    #expect(bytes("abc").parseFrequencyKHz() == nil)
  }

  // MARK: matches

  @Test
  func matchesReturnsTrueForExactMatch() {
    #expect(bytes("ABC").matches("ABC"))
  }

  @Test
  func matchesReturnsFalseForDifferentContent() {
    #expect(!bytes("ABC").matches("DEF"))
  }

  @Test
  func matchesReturnsFalseForDifferentLength() {
    #expect(!bytes("ABC").matches("AB"))
    #expect(!bytes("AB").matches("ABC"))
  }

  // MARK: trimmedMatches

  @Test
  func trimmedMatchesAfterTrimming() {
    #expect(bytes("  ABC  ").trimmedMatches("ABC"))
  }

  @Test
  func trimmedMatchesDoesNotMatchUntrimmedContent() {
    #expect(!bytes("  ABC  ").matches("ABC"))
  }

  // MARK: toString

  @Test
  func toStringConvertsBytesToString() {
    #expect(bytes("Hello").toString() == "Hello")
  }

  @Test
  func toStringReturnsEmptyStringForEmptyBytes() {
    #expect(bytes("").toString()?.isEmpty == true)
  }
}
