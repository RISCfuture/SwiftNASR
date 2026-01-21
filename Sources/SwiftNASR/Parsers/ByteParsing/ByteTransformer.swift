import Foundation

/// Type alias for a byte slice from an array.
typealias ByteSlice = ArraySlice<UInt8>

/// Transforms fixed-width byte slices into typed values.
///
/// This is the byte-based equivalent of `FixedWidthTransformer`, operating directly
/// on byte arrays for improved performance. String conversion is deferred until
/// actually needed for string fields.
struct ByteTransformer {
  private static let ddmmssParser = DDMMSSParser()

  let fields: [FixedWidthField]

  init(_ fields: [FixedWidthField]) {
    self.fields = fields
  }

  /// Parses a frequency from bytes to kHz.
  static func parseFrequency(_ bytes: ByteSlice) -> UInt? {
    bytes.parseFrequencyKHz()
  }

  /// Parses a frequency string to kHz.
  static func parseFrequency(_ string: String) -> UInt? {
    Array(string.utf8)[...].parseFrequencyKHz()
  }

  /// Applies the field transformations to byte slices.
  func applyTo(_ slices: [ByteSlice]) throws -> FixedWidthTransformedRow {
    let transformedValues = try slices.enumerated().map { index, slice -> Any? in
      switch fields[index] {
        case .recordType:
          return nil
        case .null:
          return nil
        case .string(let nullable):
          return try transformString(slice, nullable: nullable, index: index)
        case .integer(let nullable):
          return try transformInteger(slice, nullable: nullable, index: index)
        case .unsignedInteger(let nullable):
          return try transformUnsignedInteger(slice, nullable: nullable, index: index)
        case .float(let nullable):
          return try transformFloat(slice, nullable: nullable, index: index)
        case .DDMMSS(let nullable):
          return try transformDDMMSS(slice, nullable: nullable, index: index)
        case .frequency(let nullable):
          return try transformFrequency(slice, nullable: nullable, index: index)
        case let .boolean(trueValue, nullable):
          return try transformBoolean(slice, trueValue: trueValue, nullable: nullable, index: index)
        case let .datetime(formatter, nullable):
          return try transformDatetime(
            slice,
            formatter: formatter,
            nullable: nullable,
            index: index
          )
        case let .dateComponents(format, nullable):
          return try transformDateComponents(
            slice,
            format: format,
            nullable: nullable,
            index: index
          )
        case let .fixedWidthArray(width, convert, nullable, trim, emptyPlaceholders):
          return try transformFixedWidthArray(
            slice,
            width: width,
            convert: convert,
            nullable: nullable,
            trim: trim,
            emptyPlaceholders: emptyPlaceholders,
            index: index
          )
        case let .delimitedArray(delimiter, convert, nullable, trim, emptyPlaceholders):
          return try transformDelimitedArray(
            slice,
            delimiter: delimiter,
            convert: convert,
            nullable: nullable,
            trim: trim,
            emptyPlaceholders: emptyPlaceholders,
            index: index
          )
        case let .generic(convert, nullable, trim):
          return try transformGeneric(
            slice,
            convert: convert,
            nullable: nullable,
            trim: trim,
            index: index
          )
      }
    }
    return FixedWidthTransformedRow(transformedValues)
  }

  // MARK: - Private Transform Methods

  private func transformString(
    _ slice: ByteSlice,
    nullable: Nullable,
    index: Int
  ) throws -> Any? {
    try transform(slice, nullable: nullable, index: index, trim: true) { bytes in
      bytes.toString()
    }
  }

  private func transformInteger(
    _ slice: ByteSlice,
    nullable: Nullable,
    index: Int
  ) throws -> Any? {
    try transform(slice, nullable: nullable, index: index, trim: true) { bytes in
      guard let value = bytes.parseInt() else {
        let str = bytes.toString() ?? "<invalid>"
        throw FixedWidthParserError.invalidNumber(str, at: index)
      }
      return value
    }
  }

  private func transformUnsignedInteger(
    _ slice: ByteSlice,
    nullable: Nullable,
    index: Int
  ) throws -> Any? {
    try transform(slice, nullable: nullable, index: index, trim: true) { bytes in
      guard let value = bytes.parseUInt() else {
        let str = bytes.toString() ?? "<invalid>"
        throw FixedWidthParserError.invalidNumber(str, at: index)
      }
      return value
    }
  }

  private func transformFloat(
    _ slice: ByteSlice,
    nullable: Nullable,
    index: Int
  ) throws -> Any? {
    try transform(slice, nullable: nullable, index: index, trim: true) { bytes in
      guard let value = bytes.parseFloat() else {
        let str = bytes.toString() ?? "<invalid>"
        throw FixedWidthParserError.invalidNumber(str, at: index)
      }
      return value
    }
  }

  private func transformDDMMSS(
    _ slice: ByteSlice,
    nullable: Nullable,
    index: Int
  ) throws -> Any? {
    try transform(slice, nullable: nullable, index: index, trim: true) { bytes in
      // Try byte-based parsing first
      if let result = bytes.parseDDMMSS() {
        return result
      }
      // Fall back to string-based regex parser for edge cases
      guard let str = bytes.toString(),
        let result = try Self.ddmmssParser.parse(str)
      else {
        let str = bytes.toString() ?? "<invalid>"
        throw FixedWidthParserError.invalidGeodesic(str, at: index)
      }
      return result
    }
  }

  private func transformFrequency(
    _ slice: ByteSlice,
    nullable: Nullable,
    index: Int
  ) throws -> Any? {
    try transform(slice, nullable: nullable, index: index, trim: true) { bytes in
      guard let result = bytes.parseFrequencyKHz() else {
        let str = bytes.toString() ?? "<invalid>"
        throw FixedWidthParserError.invalidFrequency(str, at: index)
      }
      return result
    }
  }

  private func transformBoolean(
    _ slice: ByteSlice,
    trueValue: String,
    nullable: Nullable,
    index: Int
  ) throws -> Any? {
    try transform(slice, nullable: nullable, index: index, trim: true) { bytes in
      bytes.trimmedMatches(trueValue)
    }
  }

  private func transformDatetime(
    _ slice: ByteSlice,
    formatter: DateFormatter,
    nullable: Nullable,
    index: Int
  ) throws -> Any? {
    try transform(slice, nullable: nullable, index: index, trim: true) { bytes in
      guard let str = bytes.toString(),
        let transformed = formatter.date(from: str)
      else {
        let str = bytes.toString() ?? "<invalid>"
        throw FixedWidthParserError.invalidDate(str, at: index)
      }
      return transformed
    }
  }

  private func transformDateComponents(
    _ slice: ByteSlice,
    format: DateFormat,
    nullable: Nullable,
    index: Int
  ) throws -> Any? {
    try transform(slice, nullable: nullable, index: index, trim: true) { bytes in
      guard let str = bytes.toString(),
        let components = format.parse(str)
      else {
        let str = bytes.toString() ?? "<invalid>"
        throw FixedWidthParserError.invalidDate(str, at: index)
      }
      return components
    }
  }

  private func transformFixedWidthArray(
    _ slice: ByteSlice,
    width: Int,
    convert: ((String) throws -> Any?)?,
    nullable: Nullable,
    trim: Bool,
    emptyPlaceholders: [String]?,
    index: Int
  ) throws -> Any? {
    // Convert to string for fixed-width array operations
    guard let stringValue = slice.toString() else { return [Any?]() }

    if emptyPlaceholders?.contains(stringValue) ?? false { return [Any?]() }

    let array = try stringValue.partition(by: width).map { part in
      return try transformStringPart(
        part,
        convert: convert,
        nullable: nullable,
        trim: trim,
        index: index
      )
    }

    guard case .compact = nullable else { return array }
    return array.compactMap(\.self)
  }

  private func transformDelimitedArray(
    _ slice: ByteSlice,
    delimiter: String,
    convert: @escaping (String) throws -> Any?,
    nullable: Nullable,
    trim: Bool,
    emptyPlaceholders: [String]?,
    index: Int
  ) throws -> Any? {
    guard let stringValue = slice.toString() else { return [Any?]() }

    if stringValue.isEmpty { return [Any?]() }
    if emptyPlaceholders?.contains(stringValue) ?? false { return [Any?]() }

    do {
      let array = try stringValue.components(separatedBy: delimiter)
        .map { part in
          return try transformStringPart(
            part,
            convert: { str in try convert(str) },
            nullable: nullable,
            trim: trim,
            index: index
          )
        }
      guard case .compact = nullable else { return array }
      return array.compactMap(\.self)
    } catch {
      throw FixedWidthParserError.conversionError(stringValue, error: error, at: index)
    }
  }

  private func transformGeneric(
    _ slice: ByteSlice,
    convert: (String) throws -> Any?,
    nullable: Nullable,
    trim: Bool,
    index: Int
  ) throws -> Any? {
    guard let stringValue = trim ? slice.toTrimmedString() : slice.toString() else {
      return nil
    }
    return try transformStringValue(stringValue, convert: convert, nullable: nullable, index: index)
  }

  // MARK: - Core Transform Logic

  private func transform(
    _ slice: ByteSlice,
    nullable: Nullable,
    index: Int,
    trim: Bool = false,
    transformation: (ByteSlice) throws -> Any?
  ) throws -> Any? {
    let bytes = trim ? slice.trimmed() : slice[slice.startIndex..<slice.endIndex]

    switch nullable {
      case .notNull:
        if bytes.isEmpty {
          throw FixedWidthParserError.required(at: index)
        }
        return try transformation(bytes)
      case .blank, .compact:
        if bytes.isEmpty { return nil }
        return try transformation(bytes)
      case .sentinel(let sentinels):
        if let str = bytes.toString(), sentinels.contains(str) { return nil }
        if bytes.isEmpty { return nil }
        return try transformation(bytes)
    }
  }

  private func transformStringPart(
    _ part: String,
    convert: ((String) throws -> Any?)?,
    nullable: Nullable,
    trim: Bool,
    index: Int
  ) throws -> Any? {
    let trimmed = trim ? part.trimmingCharacters(in: .whitespaces) : part

    switch nullable {
      case .notNull:
        if trimmed.isEmpty {
          throw FixedWidthParserError.required(at: index)
        }
      case .blank, .compact:
        if trimmed.isEmpty { return nil }
      case .sentinel(let sentinels):
        if sentinels.contains(trimmed) { return nil }
    }

    if let convert {
      do {
        return try convert(trimmed)
      } catch {
        throw FixedWidthParserError.conversionError(trimmed, error: error, at: index)
      }
    }
    return trimmed
  }

  private func transformStringValue(
    _ value: String,
    convert: (String) throws -> Any?,
    nullable: Nullable,
    index: Int
  ) throws -> Any? {
    switch nullable {
      case .notNull:
        if value.isEmpty {
          throw FixedWidthParserError.required(at: index)
        }
      case .blank, .compact:
        if value.isEmpty { return nil }
      case .sentinel(let sentinels):
        if sentinels.contains(value) { return nil }
    }

    do {
      guard let transformed = try convert(value) else {
        throw ParserError.invalidValue(value)
      }
      return transformed
    } catch {
      throw FixedWidthParserError.conversionError(value, error: error, at: index)
    }
  }
}
