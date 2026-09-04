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
  func `isBlank returns true for an empty sequence`() {
    #expect(bytes("").isBlank())
  }

  @Test
  func `isBlank returns true for spaces only`() {
    #expect(bytes("   ").isBlank())
  }

  @Test
  func `isBlank returns true for tabs only`() {
    #expect(bytes("\t\t").isBlank())
  }

  @Test
  func `isBlank returns true for mixed whitespace`() {
    #expect(bytes(" \t ").isBlank())
  }

  @Test
  func `isBlank returns false for non-whitespace`() {
    #expect(!bytes("abc").isBlank())
    #expect(!bytes(" abc ").isBlank())
  }

  // MARK: trimmed

  @Test
  func `toTrimmedString removes leading spaces`() {
    #expect(bytes("   abc").toTrimmedString() == "abc")
  }

  @Test
  func `toTrimmedString removes trailing spaces`() {
    #expect(bytes("abc   ").toTrimmedString() == "abc")
  }

  @Test
  func `toTrimmedString removes leading and trailing spaces`() {
    #expect(bytes("   abc   ").toTrimmedString() == "abc")
  }

  @Test
  func `toTrimmedString removes tabs`() {
    #expect(bytes("\tabc\t").toTrimmedString() == "abc")
  }

  @Test
  func `toTrimmedString removes mixed whitespace`() {
    #expect(bytes(" \t abc \t ").toTrimmedString() == "abc")
  }

  @Test
  func `toTrimmedString handles an empty string`() {
    #expect(bytes("").toTrimmedString()?.isEmpty == true)
  }

  @Test
  func `toTrimmedString handles whitespace only`() {
    #expect(bytes("   ").toTrimmedString()?.isEmpty == true)
  }

  // MARK: parseInt

  @Test
  func `parseInt parses positive integers`() {
    #expect(bytes("123").parseInt() == 123)
  }

  @Test
  func `parseInt parses negative integers`() {
    #expect(bytes("-456").parseInt() == -456)
  }

  @Test
  func `parseInt parses a leading plus`() {
    #expect(bytes("+789").parseInt() == 789)
  }

  @Test
  func `parseInt trims whitespace`() {
    #expect(bytes("  123  ").parseInt() == 123)
  }

  @Test
  func `parseInt returns nil for empty`() {
    #expect(bytes("").parseInt() == nil)
  }

  @Test
  func `parseInt returns nil for whitespace only`() {
    #expect(bytes("   ").parseInt() == nil)
  }

  @Test
  func `parseInt returns nil for non-numeric`() {
    #expect(bytes("abc").parseInt() == nil)
  }

  @Test
  func `parseInt returns nil for mixed content`() {
    #expect(bytes("12a").parseInt() == nil)
  }

  // MARK: parseUInt

  @Test
  func `parseUInt parses unsigned integers`() {
    #expect(bytes("123").parseUInt() == 123)
  }

  @Test
  func `parseUInt parses a leading plus`() {
    #expect(bytes("+789").parseUInt() == 789)
  }

  @Test
  func `parseUInt trims whitespace`() {
    #expect(bytes("  456  ").parseUInt() == 456)
  }

  @Test
  func `parseUInt returns nil for a negative value`() {
    #expect(bytes("-123").parseUInt() == nil)
  }

  // MARK: parseFloat

  @Test
  func `parseFloat parses floats`() throws {
    #expect(abs(try #require(bytes("123.45").parseFloat()) - 123.45) < 0.001)
  }

  @Test
  func `parseFloat parses negative floats`() throws {
    #expect(abs(try #require(bytes("-123.45").parseFloat()) - -123.45) < 0.001)
  }

  @Test
  func `parseFloat trims whitespace`() throws {
    #expect(abs(try #require(bytes("  1.5  ").parseFloat()) - 1.5) < 0.001)
  }

  @Test
  func `parseFloat returns nil for empty`() {
    #expect(bytes("").parseFloat() == nil)
  }

  // MARK: parseFrequencyKHz

  @Test
  func `parseFrequencyKHz parses MHzKHz format`() {
    #expect(bytes("118.125").parseFrequencyKHz() == 118125)
  }

  @Test
  func `parseFrequencyKHz parses MHzK format with padding`() {
    #expect(bytes("118.1").parseFrequencyKHz() == 118100)
  }

  @Test
  func `parseFrequencyKHz parses MHz-only format`() {
    #expect(bytes("365").parseFrequencyKHz() == 365000)
  }

  @Test
  func `parseFrequencyKHz trims whitespace`() {
    #expect(bytes("  118.5  ").parseFrequencyKHz() == 118500)
  }

  @Test
  func `parseFrequencyKHz returns nil for an invalid format`() {
    #expect(bytes("abc").parseFrequencyKHz() == nil)
  }

  // MARK: matches

  @Test
  func `matches returns true for an exact match`() {
    #expect(bytes("ABC").matches("ABC"))
  }

  @Test
  func `matches returns false for different content`() {
    #expect(!bytes("ABC").matches("DEF"))
  }

  @Test
  func `matches returns false for a different length`() {
    #expect(!bytes("ABC").matches("AB"))
    #expect(!bytes("AB").matches("ABC"))
  }

  // MARK: trimmedMatches

  @Test
  func `trimmedMatches matches after trimming`() {
    #expect(bytes("  ABC  ").trimmedMatches("ABC"))
  }

  @Test
  func `trimmedMatches does not match untrimmed content`() {
    #expect(!bytes("  ABC  ").matches("ABC"))
  }

  // MARK: toString

  @Test
  func `toString converts bytes to a string`() {
    #expect(bytes("Hello").toString() == "Hello")
  }

  @Test
  func `toString returns an empty string for empty bytes`() {
    #expect(bytes("").toString()?.isEmpty == true)
  }
}
