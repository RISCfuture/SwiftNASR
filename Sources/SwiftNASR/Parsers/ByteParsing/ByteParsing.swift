import Foundation

extension RandomAccessCollection<UInt8> {
  // MARK: - Properties

  /// Returns the first byte, or nil if empty.
  @inlinable public var firstByte: UInt8? {
    isEmpty ? nil : self[startIndex]
  }

  // MARK: - Whitespace Handling

  /// Returns true if all bytes are whitespace or the collection is empty.
  @inlinable
  public func isBlank() -> Bool {
    allSatisfy { ASCII.isWhitespace($0) }
  }

  /// Returns the range of bytes excluding leading and trailing whitespace.
  @inlinable
  public func trimmedRange() -> Range<Index> {
    var start = startIndex
    var end = endIndex

    // Skip leading whitespace
    while start < end && ASCII.isWhitespace(self[start]) {
      formIndex(after: &start)
    }

    // Skip trailing whitespace
    while end > start {
      let prev = index(before: end)
      if !ASCII.isWhitespace(self[prev]) { break }
      end = prev
    }

    return start..<end
  }

  /// Returns a slice with leading and trailing whitespace removed.
  @inlinable
  public func trimmed() -> SubSequence {
    self[trimmedRange()]
  }

  // MARK: - String Conversion

  /// Converts the bytes to a string using ISO-Latin-1 encoding.
  @inlinable
  public func toString() -> String? {
    if isEmpty { return "" }
    return String(bytes: self, encoding: .isoLatin1)
  }

  /// Converts the bytes to a trimmed string (whitespace removed) using ISO-Latin-1 encoding.
  @inlinable
  public func toTrimmedString() -> String? {
    let range = trimmedRange()
    if range.isEmpty { return "" }
    return String(bytes: self[range], encoding: .isoLatin1)
  }

  // MARK: - Integer Parsing

  /// Parses the bytes as a signed integer.
  @inlinable
  public func parseInt() -> Int? {
    let range = trimmedRange()
    guard range.lowerBound < range.upperBound else { return nil }

    var index = range.lowerBound
    let sign: Int

    // Check for leading sign
    if self[index] == ASCII.minus {
      sign = -1
      formIndex(after: &index)
    } else if self[index] == ASCII.plus {
      sign = 1
      formIndex(after: &index)
    } else {
      sign = 1
    }

    // Must have at least one digit
    guard index < range.upperBound else { return nil }

    var result = 0
    while index < range.upperBound {
      let byte = self[index]
      guard ASCII.isDigit(byte) else { return nil }
      result = result * 10 + Int(byte - ASCII.zero)
      formIndex(after: &index)
    }

    return result * sign
  }

  /// Parses the bytes as an unsigned integer.
  @inlinable
  public func parseUInt() -> UInt? {
    let range = trimmedRange()
    guard range.lowerBound < range.upperBound else { return nil }

    var index = range.lowerBound

    // Optional leading plus
    if self[index] == ASCII.plus {
      formIndex(after: &index)
    }

    // Must have at least one digit
    guard index < range.upperBound else { return nil }

    var result: UInt = 0
    while index < range.upperBound {
      let byte = self[index]
      guard ASCII.isDigit(byte) else { return nil }
      result = result * 10 + UInt(byte - ASCII.zero)
      formIndex(after: &index)
    }

    return result
  }

  /// Parses the bytes as a Float.
  @inlinable
  public func parseFloat() -> Float? {
    guard let string = toTrimmedString(), !string.isEmpty else { return nil }
    return Float(string)
  }

  /// Parses the bytes as a Double.
  @inlinable
  public func parseDouble() -> Double? {
    guard let string = toTrimmedString(), !string.isEmpty else { return nil }
    return Double(string)
  }

  // MARK: - Frequency Parsing

  /// Parses a frequency in the format "NNN.NNN" or "NNN" as kilohertz (kHz).
  ///
  /// For example:
  /// - "118.125" returns 118125 (kHz)
  /// - "118.1" returns 118100 (kHz)
  /// - "365" returns 365000 (kHz)
  @inlinable
  public func parseFrequencyKHz() -> UInt? {
    let range = trimmedRange()
    guard range.lowerBound < range.upperBound else { return nil }

    var index = range.lowerBound
    var mhzPart: UInt = 0
    var khzPart: UInt = 0
    var khzDigits = 0
    var foundDecimal = false

    // Parse MHz part
    while index < range.upperBound {
      let byte = self[index]
      if byte == ASCII.period {
        foundDecimal = true
        formIndex(after: &index)
        break
      }
      guard ASCII.isDigit(byte) else { return nil }
      mhzPart = mhzPart * 10 + UInt(byte - ASCII.zero)
      formIndex(after: &index)
    }

    // Parse kHz part (after decimal)
    if foundDecimal {
      while index < range.upperBound && khzDigits < 3 {
        let byte = self[index]
        guard ASCII.isDigit(byte) else { return nil }
        khzPart = khzPart * 10 + UInt(byte - ASCII.zero)
        khzDigits += 1
        formIndex(after: &index)
      }

      // Pad to 3 digits
      while khzDigits < 3 {
        khzPart *= 10
        khzDigits += 1
      }
    }

    return mhzPart * 1000 + khzPart
  }

  // MARK: - Comparison

  /// Returns true if the bytes match the given ASCII string.
  @inlinable
  public func matches(_ string: String) -> Bool {
    var index = startIndex
    for char in string.utf8 {
      guard index < endIndex else { return false }
      guard self[index] == char else { return false }
      formIndex(after: &index)
    }
    return index == endIndex
  }

  /// Returns true if the trimmed bytes match the given ASCII string.
  @inlinable
  public func trimmedMatches(_ string: String) -> Bool {
    trimmed().matches(string)
  }

  // MARK: - Byte Access

  /// Returns the byte at the specified offset from the start.
  @inlinable
  public func byte(at offset: Int) -> UInt8? {
    let idx = index(startIndex, offsetBy: offset)
    guard idx < endIndex else { return nil }
    return self[idx]
  }
}
