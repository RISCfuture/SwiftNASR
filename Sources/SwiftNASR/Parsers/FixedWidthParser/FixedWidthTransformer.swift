import Foundation
@preconcurrency import RegexBuilder

enum Nullable {
  case notNull
  case blank
  case compact
  case sentinel(_ sentinels: [String])
}

/// Date formats for parsing date strings directly into DateComponents.
enum DateFormat {
  /// "yyyy" - year only (e.g., "2023")
  case yearOnly
  /// "MM/yyyy" - month/year (e.g., "01/2023")
  case monthYear
  /// "MMddyyyy" - month day year without delimiters (e.g., "01152023")
  case monthDayYear
  /// "MM/dd/yyyy" - month/day/year with slashes (e.g., "01/15/2023")
  case monthDayYearSlash
  /// "yyyy/MM/dd" - year/month/day with slashes (e.g., "2023/01/15")
  case yearMonthDaySlash
  /// "yyyy/MM" - year/month with slash (e.g., "2023/01")
  case yearMonthSlash
  /// "dd MMM yyyy" - day month year with spaces (e.g., "15 Jan 2023")
  case dayMonthYear

  private static let monthAbbreviations: [String: Int] = [
    "JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
    "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12
  ]

  /// Parse a string into DateComponents using this format.
  func parse(_ string: String) -> DateComponents? {
    switch self {
      case .yearOnly:
        guard let year = Int(string) else { return nil }
        return DateComponents(year: year)
      case .monthYear:
        let parts = string.split(separator: "/")
        guard parts.count == 2,
          let month = Int(parts[0]),
          let year = Int(parts[1])
        else { return nil }
        return DateComponents(year: year, month: month)
      case .monthDayYear:
        guard string.count == 8,
          let month = Int(string.prefix(2)),
          let day = Int(string.dropFirst(2).prefix(2)),
          let year = Int(string.suffix(4))
        else { return nil }
        return DateComponents(year: year, month: month, day: day)
      case .monthDayYearSlash:
        let parts = string.split(separator: "/")
        guard parts.count == 3,
          let month = Int(parts[0]),
          let day = Int(parts[1]),
          let year = Int(parts[2])
        else { return nil }
        return DateComponents(year: year, month: month, day: day)
      case .yearMonthDaySlash:
        let parts = string.split(separator: "/")
        guard parts.count == 3,
          let year = Int(parts[0]),
          let month = Int(parts[1]),
          let day = Int(parts[2])
        else { return nil }
        return DateComponents(year: year, month: month, day: day)
      case .yearMonthSlash:
        let parts = string.split(separator: "/")
        guard parts.count == 2,
          let year = Int(parts[0]),
          let month = Int(parts[1])
        else { return nil }
        return DateComponents(year: year, month: month)
      case .dayMonthYear:
        let parts = string.split(separator: " ")
        guard parts.count == 3,
          let day = Int(parts[0]),
          let month = Self.monthAbbreviations[parts[1].uppercased()],
          let year = Int(parts[2])
        else { return nil }
        return DateComponents(year: year, month: month, day: day)
    }
  }
}

enum FixedWidthField {
  case recordType
  case null
  case string(nullable: Nullable = .notNull)
  case integer(nullable: Nullable = .notNull)
  case unsignedInteger(nullable: Nullable = .notNull)
  case float(nullable: Nullable = .notNull)
  case DDMMSS(nullable: Nullable = .notNull)
  case frequency(nullable: Nullable = .notNull)
  case boolean(trueValue: String = "Y", nullable: Nullable = .notNull)
  case datetime(formatter: DateFormatter, nullable: Nullable = .notNull)
  case dateComponents(format: DateFormat, nullable: Nullable = .notNull)
  case fixedWidthArray(
    width: Int = 1,
    convert: ((String) throws -> Any?)? = nil,
    nullable: Nullable = .notNull,
    trim: Bool = true,
    emptyPlaceholders: [String]? = nil
  )
  case delimitedArray(
    delimiter: String,
    convert: (String) throws -> Any?,
    nullable: Nullable = .notNull,
    trim: Bool = true,
    emptyPlaceholders: [String]? = nil
  )
  case generic(_ convert: (String) throws -> Any?, nullable: Nullable = .notNull, trim: Bool = true)
}

struct FixedWidthTransformer {
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

  func applyTo(_ values: [String]) throws -> [Any?] {
    return try values.enumerated().map { index, value in
      switch fields[index] {
        case .recordType: return nil
        case .null: return nil
        case .string(let nullable):
          return try transform(value, nullable: nullable, index: index, trim: true) { $0 }
        case .integer(let nullable):
          return try transform(value, nullable: nullable, index: index, trim: true) { str in
            guard let transformed = Int(str) else {
              throw FixedWidthParserError.invalidNumber(str, at: index)
            }
            return transformed
          }
        case .unsignedInteger(let nullable):
          return try transform(value, nullable: nullable, index: index, trim: true) { str in
            guard let transformed = UInt(str) else {
              throw FixedWidthParserError.invalidNumber(str, at: index)
            }
            return transformed
          }
        case .float(let nullable):
          return try transform(value, nullable: nullable, index: index, trim: true) { str in
            guard let transformed = Float(str) else {
              throw FixedWidthParserError.invalidNumber(str, at: index)
            }
            return transformed
          }
        case .DDMMSS(let nullable):
          return try transform(value, nullable: nullable, index: index, trim: true) { str in
            guard let result = try Self.ddmmssParser.parse(str) else {
              throw FixedWidthParserError.invalidGeodesic(str, at: index)
            }
            return result
          }
        case .frequency(let nullable):
          return try transform(value, nullable: nullable, index: index, trim: true) { str in
            guard let result = Self.parseFrequency(str) else {
              throw FixedWidthParserError.invalidFrequency(str, at: index)
            }
            return result
          }
        case let .boolean(trueValue, nullable):
          return try transform(value, nullable: nullable, index: index, trim: true) { str in
            return str == trueValue
          }
        case let .datetime(formatter, nullable):
          return try transform(value, nullable: nullable, index: index, trim: true) { str in
            guard let transformed = formatter.date(from: str) else {
              throw FixedWidthParserError.invalidDate(str, at: index)
            }
            return transformed
          }
        case let .dateComponents(format, nullable):
          return try transform(value, nullable: nullable, index: index, trim: true) { str in
            guard let components = format.parse(str) else {
              throw FixedWidthParserError.invalidDate(str, at: index)
            }
            return components
          }
        case let .fixedWidthArray(width, convert, nullable, trim, emptyPlaceholders):
          if emptyPlaceholders?.contains(value) ?? false { return [Any?]() }
          let array = try value.partition(by: width).map { part in
            return try transform(part, nullable: nullable, index: index, trim: trim) { str in
              if let convert {
                do {
                  return try convert(str)
                } catch {
                  throw FixedWidthParserError.conversionError(str, error: error, at: index)
                }
              } else {
                return str
              }
            }
          }
          guard case .compact = nullable else { return array }
          return array.compactMap(\.self)
        case let .delimitedArray(
          delimiter,
          convert,
          nullable,
          trim,
          emptyPlaceholders
        ):
          if value.isEmpty { return [Any?]() }
          if emptyPlaceholders?.contains(value) ?? false { return [Any?]() }

          do {
            let array = try value.components(separatedBy: delimiter)
              .map { part in
                return try transform(part, nullable: nullable, index: index, trim: trim) { str in
                  do {
                    return try convert(str)
                  } catch {
                    throw FixedWidthParserError.conversionError(str, error: error, at: index)
                  }
                }
              }
            guard case .compact = nullable else { return array }
            return array.compactMap(\.self)
          } catch {
            throw FixedWidthParserError.conversionError(value, error: error, at: index)
          }
        case let .generic(convert, nullable, trim):
          return try transform(value, nullable: nullable, index: index, trim: trim) { str in
            do {
              guard let transformed = try convert(str) else {
                throw ParserError.invalidValue(str)
              }
              return transformed
            } catch {
              throw FixedWidthParserError.conversionError(str, error: error, at: index)
            }
          }
      }
    }
  }

  private func transform(
    _ value: String,
    nullable: Nullable,
    index: Int,
    trim: Bool = false,
    transformation: (String) throws -> Any?
  ) throws -> Any? {
    let trimmed = trim ? value.trimmingCharacters(in: .whitespaces) : value
    switch nullable {
      case .notNull:
        if trimmed.isEmpty {
          throw FixedWidthParserError.required(at: index)
        }
        return try transformation(trimmed)
      case .blank, .compact:
        if trimmed.isEmpty { return nil }
        return try transformation(trimmed)
      case .sentinel(let sentinels):
        if sentinels.contains(trimmed) { return nil }
        return try transformation(trimmed)
    }
  }
}
