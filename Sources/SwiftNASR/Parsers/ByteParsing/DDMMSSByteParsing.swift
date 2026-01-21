extension RandomAccessCollection<UInt8> {
  /// Parses a degree-minute-second coordinate string to arc-seconds.
  ///
  /// Expected format: `DD-MM-SS.SSSS[NESW]` or `DDD-MM-SS.SSSS[NESW]`
  /// Examples:
  /// - `"40-30-32.5412N"` → 145832.5412
  /// - `"122-15-30.1234W"` → -440130.1234
  ///
  /// - Returns: Arc-seconds as Float (positive for N/E, negative for S/W), or nil if
  /// parsing fails or the input is blank.
  @inlinable
  public func parseDDMMSS() -> Float? {
    let range = trimmedRange()
    guard range.lowerBound < range.upperBound else { return nil }

    var index = range.lowerBound

    // Parse degrees (2-3 digits)
    var degrees = 0
    var degreeDigits = 0
    while index < range.upperBound && ASCII.isDigit(self[index]) {
      degrees = degrees * 10 + Int(self[index] - ASCII.zero)
      degreeDigits += 1
      formIndex(after: &index)
    }

    // Must have 2-3 degree digits
    guard degreeDigits >= 2 && degreeDigits <= 3 else { return nil }

    // Expect hyphen
    guard index < range.upperBound && self[index] == ASCII.minus else { return nil }
    formIndex(after: &index)

    // Parse minutes (2 digits)
    guard index < range.upperBound && ASCII.isDigit(self[index]) else { return nil }
    var minutes = Int(self[index] - ASCII.zero)
    formIndex(after: &index)

    guard index < range.upperBound && ASCII.isDigit(self[index]) else { return nil }
    minutes = minutes * 10 + Int(self[index] - ASCII.zero)
    formIndex(after: &index)

    // Expect hyphen
    guard index < range.upperBound && self[index] == ASCII.minus else { return nil }
    formIndex(after: &index)

    // Parse seconds integer part (2 digits)
    guard index < range.upperBound && ASCII.isDigit(self[index]) else { return nil }
    var secondsInt = Int(self[index] - ASCII.zero)
    formIndex(after: &index)

    guard index < range.upperBound && ASCII.isDigit(self[index]) else { return nil }
    secondsInt = secondsInt * 10 + Int(self[index] - ASCII.zero)
    formIndex(after: &index)

    // Expect decimal point
    guard index < range.upperBound && self[index] == ASCII.period else { return nil }
    formIndex(after: &index)

    // Parse seconds fractional part (1+ digits)
    var fractionNumerator = 0
    var fractionDenominator = 1
    while index < range.upperBound && ASCII.isDigit(self[index]) {
      fractionNumerator = fractionNumerator * 10 + Int(self[index] - ASCII.zero)
      fractionDenominator *= 10
      formIndex(after: &index)
    }

    // Must have at least one fractional digit
    guard fractionDenominator > 1 else { return nil }

    // Parse quadrant (N, E, S, W)
    guard index < range.upperBound else { return nil }
    let quadrant = self[index]
    formIndex(after: &index)

    // Should be at end of string
    guard index == range.upperBound else { return nil }

    // Determine sign based on quadrant
    let sign: Float
    switch quadrant {
      case ASCII.N, ASCII.E:
        sign = 1.0
      case ASCII.S, ASCII.W:
        sign = -1.0
      default:
        return nil
    }

    // Calculate arc-seconds: degrees*3600 + minutes*60 + seconds
    let seconds = Float(secondsInt) + Float(fractionNumerator) / Float(fractionDenominator)
    let arcSeconds = Float(degrees) * 3600.0 + Float(minutes) * 60.0 + seconds

    return arcSeconds * sign
  }
}
