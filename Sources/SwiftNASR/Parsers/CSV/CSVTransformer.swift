import Foundation

/// CSVTransformer provides declarative transformations for CSV fields, similar to FixedWidthTransformer
struct CSVTransformer {
  static var yearOnly: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "yyyy"
    df.timeZone = zulu
    return df
  }
  static var monthYear: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "MM/yyyy"
    df.timeZone = zulu
    return df
  }
  static var monthDayYear: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "MMddyyyy"
    df.timeZone = zulu
    return df
  }
  static var monthDayYearSlash: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "MM/dd/yyyy"
    df.timeZone = zulu
    return df
  }
  // CSV date formats (FAA CSV uses yyyy/MM/dd and yyyy/MM)
  static var yearMonthDaySlash: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "yyyy/MM/dd"
    df.timeZone = zulu
    return df
  }
  static var yearMonthSlash: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "yyyy/MM"
    df.timeZone = zulu
    return df
  }
  static var dayMonthYear: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "dd MMM yyyy"
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = zulu
    return df
  }

  private static let ddmmssParser = DDMMSSParser()

  let fields: [FixedWidthField]

  init(_ fields: [FixedWidthField]) {
    self.fields = fields
  }

  static func parseFrequency(_ string: String) -> UInt? {
    let parts = string.split(separator: Character("."))
    guard parts.count == 1 || parts.count == 2 else {
      return nil
    }

    if parts.count == 2 {
      let MHzString = parts[0]
      let KHzString = parts[1]
      guard let MHz = UInt(MHzString) else {
        return nil
      }
      guard let KHz = UInt(KHzString.padding(toLength: 3, withPad: "0", startingAt: 0)) else {
        return nil
      }
      return MHz * 1000 + KHz
    }
    guard let MHz = UInt(parts[0]) else {
      return nil
    }
    return MHz * 1000
  }

  /// Apply transformations to CSV row fields at specified indices
  func applyTo(_ values: [String], indices: [Int]) throws -> [Any?] {
    guard indices.count == fields.count else {
      throw CSVParserError.fieldCountMismatch(expected: fields.count, actual: indices.count)
    }

    return try fields.enumerated().map { fieldIndex, field in
      let csvIndex = indices[fieldIndex]

      // Handle negative indices (meaning field not available in CSV)
      guard csvIndex >= 0 else {
        // For CSV, negative index means field not available, return nil
        return nil
      }

      // Handle out of bounds indices
      guard csvIndex < values.count else {
        // For CSV, out of bounds typically means empty/null
        return try transform(
          "",
          nullable: extractNullable(from: field),
          index: csvIndex,
          trim: true
        ) { _ in nil }
      }

      let value = values[csvIndex]

      switch field {
        case .recordType: return nil
        case .null: return nil
        case .string(let nullable):
          return try transform(value, nullable: nullable, index: csvIndex, trim: true) { $0 }
        case .integer(let nullable):
          return try transform(value, nullable: nullable, index: csvIndex, trim: true) { str in
            guard let transformed = Int(str) else {
              throw CSVParserError.invalidNumber(str, at: csvIndex)
            }
            return transformed
          }
        case .unsignedInteger(let nullable):
          return try transform(value, nullable: nullable, index: csvIndex, trim: true) { str in
            guard let transformed = UInt(str) else {
              throw CSVParserError.invalidNumber(str, at: csvIndex)
            }
            return transformed
          }
        case .float(let nullable):
          return try transform(value, nullable: nullable, index: csvIndex, trim: true) { str in
            guard let transformed = Float(str) else {
              throw CSVParserError.invalidNumber(str, at: csvIndex)
            }
            return transformed
          }
        case .DDMMSS(let nullable):
          return try transform(value, nullable: nullable, index: csvIndex, trim: true) { str in
            guard let parsed = try? Self.ddmmssParser.parse(str) else {
              throw CSVParserError.invalidGeodesic(str, at: csvIndex)
            }
            return parsed
          }
        case .frequency(let nullable):
          return try transform(value, nullable: nullable, index: csvIndex, trim: true) { str in
            guard let transformed = Self.parseFrequency(str) else {
              throw CSVParserError.invalidFrequency(str, at: csvIndex)
            }
            return transformed
          }
        case let .boolean(trueValue, nullable):
          return try transform(value, nullable: nullable, index: csvIndex, trim: true) { str in
            return str == trueValue
          }
        case let .datetime(formatter, nullable):
          return try transform(value, nullable: nullable, index: csvIndex, trim: true) { str in
            guard let transformed = formatter.date(from: str) else {
              throw CSVParserError.invalidDate(str, at: csvIndex)
            }
            return transformed
          }
        case let .dateComponents(format, nullable):
          return try transform(value, nullable: nullable, index: csvIndex, trim: true) { str in
            guard let components = format.parse(str) else {
              throw CSVParserError.invalidDate(str, at: csvIndex)
            }
            return components
          }
        case let .fixedWidthArray(width, convert, nullable, trim, emptyPlaceholders):
          return try transform(value, nullable: nullable, index: csvIndex, trim: trim) { str in
            return try parseFixedWidthArray(
              str,
              width: width,
              convert: convert,
              trim: trim,
              emptyPlaceholders: emptyPlaceholders
            )
          }
        case let .delimitedArray(
          delimiter,
          convert,
          nullable,
          trim,
          emptyPlaceholders
        ):
          return try transform(value, nullable: nullable, index: csvIndex, trim: trim) { str in
            return try parseDelimitedArray(
              str,
              delimiter: delimiter,
              convert: convert,
              trim: trim,
              emptyPlaceholders: emptyPlaceholders
            )
          }
        case let .generic(convert, nullable, trim):
          return try transform(value, nullable: nullable, index: csvIndex, trim: trim, convert)
      }
    }
  }

  private func extractNullable(from field: FixedWidthField) -> Nullable {
    switch field {
      case .string(let nullable): return nullable
      case .integer(let nullable): return nullable
      case .unsignedInteger(let nullable): return nullable
      case .float(let nullable): return nullable
      case .DDMMSS(let nullable): return nullable
      case .frequency(let nullable): return nullable
      case .boolean(_, let nullable): return nullable
      case .datetime(_, let nullable): return nullable
      case .dateComponents(_, let nullable): return nullable
      case .fixedWidthArray(_, _, let nullable, _, _): return nullable
      case .delimitedArray(_, _, let nullable, _, _): return nullable
      case .generic(_, let nullable, _): return nullable
      default: return .notNull
    }
  }

  private func transform(
    _ value: String,
    nullable: Nullable,
    index: Int,
    trim: Bool,
    _ convert: (String) throws -> Any?
  ) throws -> Any? {
    let trimmedValue = trim ? value.trimmingCharacters(in: .whitespaces) : value

    // Check nullable conditions
    switch nullable {
      case .notNull:
        if trimmedValue.isEmpty {
          throw CSVParserError.required(at: index)
        }
      case .blank:
        if trimmedValue.isEmpty {
          return nil
        }
      case .compact:
        // For CSV, compact typically means empty string is nil
        if trimmedValue.isEmpty {
          return nil
        }
      case .sentinel(let sentinels):
        if sentinels.contains(trimmedValue) || trimmedValue.isEmpty {
          return nil
        }
    }

    do {
      return try convert(trimmedValue)
    } catch let error as CSVParserError {
      throw error
    } catch {
      throw CSVParserError.conversionError(trimmedValue, error: error, at: index)
    }
  }

  private func parseFixedWidthArray(
    _ value: String,
    width: Int,
    convert: ((String) throws -> Any?)?,
    trim: Bool,
    emptyPlaceholders: [String]?
  ) throws -> [Any] {
    var result = [Any]()
    var index = value.startIndex

    while index < value.endIndex {
      let endIndex =
        value.index(index, offsetBy: width, limitedBy: value.endIndex) ?? value.endIndex
      let substring = String(value[index..<endIndex])
      let trimmedSubstring = trim ? substring.trimmingCharacters(in: .whitespaces) : substring

      if !trimmedSubstring.isEmpty {
        if let placeholders = emptyPlaceholders, placeholders.contains(trimmedSubstring) {
          // Skip empty placeholders
        } else if let convert {
          if let converted = try convert(trimmedSubstring) {
            result.append(converted)
          }
        } else {
          result.append(trimmedSubstring)
        }
      }

      index = endIndex
    }

    return result
  }

  private func parseDelimitedArray(
    _ value: String,
    delimiter: String,
    convert: (String) throws -> Any?,
    trim: Bool,
    emptyPlaceholders: [String]?
  ) throws -> [Any] {
    let parts = value.components(separatedBy: delimiter)
    var result = [Any]()

    for part in parts {
      let trimmedPart = trim ? part.trimmingCharacters(in: .whitespaces) : part

      if !trimmedPart.isEmpty {
        if let placeholders = emptyPlaceholders, placeholders.contains(trimmedPart) {
          // Skip empty placeholders
        } else {
          if let converted = try convert(trimmedPart) {
            result.append(converted)
          }
        }
      }
    }

    return result
  }
}

enum CSVParserError: Swift.Error, CustomStringConvertible {
  case fieldCountMismatch(expected: Int, actual: Int)
  case required(at: Int)
  case invalidNumber(_ value: String, at: Int)
  case invalidDate(_ value: String, at: Int)
  case invalidFrequency(_ value: String, at: Int)
  case invalidGeodesic(_ value: String, at: Int)
  case conversionError(_ value: String, error: Swift.Error, at: Int)
  case invalidValue(_ value: String, at: Int)

  var description: String {
    switch self {
      case let .fieldCountMismatch(expected, actual):
        return "Field count mismatch: expected \(expected), got \(actual)"
      case let .required(field):
        return "Field #\(field) is required"
      case let .invalidNumber(value, field):
        return "Field #\(field) contains invalid number '\(value)'"
      case let .invalidDate(value, field):
        return "Field #\(field) contains invalid date '\(value)'"
      case let .invalidFrequency(value, field):
        return "Field #\(field) contains invalid frequency '\(value)'"
      case let .invalidGeodesic(value, field):
        return "Field #\(field) contains invalid geodesic '\(value)'"
      case let .conversionError(_, error, field):
        return "Field #\(field) contains invalid value: \(error)"
      case let .invalidValue(value, field):
        return "Field #\(field) contains invalid value '\(value)'"
    }
  }
}
