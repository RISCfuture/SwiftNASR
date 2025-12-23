import Foundation

/// A row of transformed CSV values with typed access by column name.
struct TransformedRow {
  private let values: [Any?]
  private let columnToIndex: [String: Int]

  init(values: [Any?], columnToIndex: [String: Int]) {
    self.values = values
    self.columnToIndex = columnToIndex
  }

  // MARK: - Subscripts

  /// Access a required field by column name with type inference.
  ///
  /// - Parameter columnName: The column name to access.
  /// - Returns: The transformed value cast to the expected type.
  /// - Throws: `CSVParserError.unknownColumn` if column not found,
  ///           `CSVParserError.requiredColumn` if value is nil,
  ///           `CSVParserError.typeMismatch` if value cannot be cast to expected type.
  subscript<T>(_ columnName: String) -> T {
    get throws {
      guard let index = columnToIndex[columnName] else {
        throw CSVParserError.unknownColumn(columnName, available: Array(columnToIndex.keys))
      }
      guard let anyValue = values[index] else {
        throw CSVParserError.requiredColumn(columnName)
      }
      guard let value = anyValue as? T else {
        throw CSVParserError.typeMismatch(
          column: columnName,
          expected: String(describing: T.self),
          actual: String(describing: type(of: anyValue))
        )
      }
      return value
    }
  }

  /// Access an optional field by column name with type inference.
  ///
  /// - Parameter columnName: The column name to access.
  /// - Returns: The transformed value cast to the expected type, or nil if the value is nil.
  /// - Throws: `CSVParserError.unknownColumn` if column not found,
  ///           `CSVParserError.typeMismatch` if value cannot be cast to expected type.
  subscript<T>(optional columnName: String) -> T? {
    get throws {
      guard let index = columnToIndex[columnName] else {
        throw CSVParserError.unknownColumn(columnName, available: Array(columnToIndex.keys))
      }
      guard let anyValue = values[index] else {
        return nil
      }
      guard let value = anyValue as? T else {
        throw CSVParserError.typeMismatch(
          column: columnName,
          expected: String(describing: T.self),
          actual: String(describing: type(of: anyValue))
        )
      }
      return value
    }
  }
}

/// CSVTransformer provides declarative transformations for CSV fields, similar to FixedWidthTransformer
struct CSVTransformer {
  // MARK: - Type Properties

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

  // MARK: - Instance Properties

  /// The named field specifications for transformation.
  let fields: [NamedField]

  // MARK: - Initializer

  /// Initialize with named column mappings for header-based parsing.
  init(_ fields: [NamedField]) {
    self.fields = fields
  }

  // MARK: - Type Methods

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

  // MARK: - Instance Methods

  /// Apply transformations using header-based row access.
  ///
  /// This method uses the column names from the field specifications to look up values
  /// in the CSV row, making parsers resilient to column order changes.
  ///
  /// - Parameter row: The CSV row with header-based access.
  /// - Returns: A `TransformedRow` with typed access by column name.
  /// - Throws: `CSVParserError` if transformation fails.
  func applyTo(_ row: CSVRow) throws -> TransformedRow {
    var columnToIndex = [String: Int]()
    for (index, field) in fields.enumerated() {
      columnToIndex[field.columnName] = index
    }

    let values = try fields.map { namedField in
      try transformNamedField(namedField, row: row)
    }

    return TransformedRow(values: values, columnToIndex: columnToIndex)
  }

  private func transformNamedField(_ namedField: NamedField, row: CSVRow) throws -> Any? {
    let columnName = namedField.columnName
    let field = namedField.field

    // Get value from row, handling missing columns for nullable fields
    let value: String
    do {
      value = try row[columnName]
    } catch CSVParserError.unknownColumn {
      // Column doesn't exist - return nil for nullable fields, rethrow for required
      let nullable = extractNullable(from: field)
      if case .notNull = nullable {
        throw CSVParserError.unknownColumn(columnName, available: row.headerMap.columnNames)
      }
      return nil
    }

    switch field {
      case .recordType: return nil
      case .null: return nil
      case .string(let nullable):
        return try transformColumn(value, nullable: nullable, column: columnName, trim: true) { $0 }
      case .integer(let nullable):
        return try transformColumn(value, nullable: nullable, column: columnName, trim: true) {
          str in
          guard let transformed = Int(str) else {
            throw CSVParserError.invalidNumberInColumn(str, column: columnName)
          }
          return transformed
        }
      case .unsignedInteger(let nullable):
        return try transformColumn(value, nullable: nullable, column: columnName, trim: true) {
          str in
          guard let transformed = UInt(str) else {
            throw CSVParserError.invalidNumberInColumn(str, column: columnName)
          }
          return transformed
        }
      case .float(let nullable):
        return try transformColumn(value, nullable: nullable, column: columnName, trim: true) {
          str in
          guard let transformed = Float(str) else {
            throw CSVParserError.invalidNumberInColumn(str, column: columnName)
          }
          return transformed
        }
      case .DDMMSS(let nullable):
        return try transformColumn(value, nullable: nullable, column: columnName, trim: true) {
          str in
          guard let parsed = try? Self.ddmmssParser.parse(str) else {
            throw CSVParserError.invalidGeodesicInColumn(str, column: columnName)
          }
          return parsed
        }
      case .frequency(let nullable):
        return try transformColumn(value, nullable: nullable, column: columnName, trim: true) {
          str in
          guard let transformed = Self.parseFrequency(str) else {
            throw CSVParserError.invalidFrequencyInColumn(str, column: columnName)
          }
          return transformed
        }
      case let .boolean(trueValue, nullable):
        return try transformColumn(value, nullable: nullable, column: columnName, trim: true) {
          str in
          return str == trueValue
        }
      case let .datetime(formatter, nullable):
        return try transformColumn(value, nullable: nullable, column: columnName, trim: true) {
          str in
          guard let transformed = formatter.date(from: str) else {
            throw CSVParserError.invalidDateInColumn(str, column: columnName)
          }
          return transformed
        }
      case let .dateComponents(format, nullable):
        return try transformColumn(value, nullable: nullable, column: columnName, trim: true) {
          str in
          guard let components = format.parse(str) else {
            throw CSVParserError.invalidDateInColumn(str, column: columnName)
          }
          return components
        }
      case let .fixedWidthArray(width, convert, nullable, trim, emptyPlaceholders):
        return try transformColumn(value, nullable: nullable, column: columnName, trim: trim) {
          str in
          return try parseFixedWidthArray(
            str,
            width: width,
            convert: convert,
            trim: trim,
            emptyPlaceholders: emptyPlaceholders
          )
        }
      case let .delimitedArray(delimiter, convert, nullable, trim, emptyPlaceholders):
        return try transformColumn(value, nullable: nullable, column: columnName, trim: trim) {
          str in
          return try parseDelimitedArray(
            str,
            delimiter: delimiter,
            convert: convert,
            trim: trim,
            emptyPlaceholders: emptyPlaceholders
          )
        }
      case let .generic(convert, nullable, trim):
        return try transformColumn(
          value,
          nullable: nullable,
          column: columnName,
          trim: trim,
          convert
        )
    }
  }

  private func transformColumn(
    _ value: String,
    nullable: Nullable,
    column: String,
    trim: Bool,
    _ convert: (String) throws -> Any?
  ) throws -> Any? {
    let trimmedValue = trim ? value.trimmingCharacters(in: .whitespaces) : value

    switch nullable {
      case .notNull:
        if trimmedValue.isEmpty {
          throw CSVParserError.requiredColumn(column)
        }
      case .blank, .compact:
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
      throw CSVParserError.conversionErrorInColumn(trimmedValue, error: error, column: column)
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

  // MARK: - Subtype

  /// A field specification that pairs a column name with its transformation.
  struct NamedField {
    let columnName: String
    let field: FixedWidthField

    init(_ columnName: String, _ field: FixedWidthField) {
      self.columnName = columnName
      self.field = field
    }
  }
}

enum CSVParserError: Swift.Error, CustomStringConvertible {
  case fieldCountMismatch(expected: Int, actual: Int)
  case unknownColumn(_ column: String, available: [String])
  case columnIndexOutOfBounds(column: String, index: Int, rowFieldCount: Int)
  case missingRequiredColumns(_ columns: [String])
  case requiredColumn(_ column: String)
  case invalidNumberInColumn(_ value: String, column: String)
  case invalidDateInColumn(_ value: String, column: String)
  case invalidFrequencyInColumn(_ value: String, column: String)
  case invalidGeodesicInColumn(_ value: String, column: String)
  case conversionErrorInColumn(_ value: String, error: Swift.Error, column: String)
  case invalidValueInColumn(_ value: String, column: String)
  case typeMismatch(column: String, expected: String, actual: String)

  var description: String {
    switch self {
      case let .fieldCountMismatch(expected, actual):
        return String(localized: "Field count mismatch: expected \(expected), got \(actual)")
      case let .unknownColumn(column, available):
        let availableStr = available.joined(separator: ", ")
        return String(localized: "Unknown CSV column ‘\(column)’. Available: \(availableStr)")
      case let .columnIndexOutOfBounds(column, index, rowFieldCount):
        return String(
          localized:
            "Column ‘\(column)’ at index \(index) exceeds row field count (\(rowFieldCount))"
        )
      case let .missingRequiredColumns(columns):
        let columnsStr = columns.joined(separator: ", ")
        return String(localized: "Missing required CSV columns: \(columnsStr)")
      case let .requiredColumn(column):
        return String(localized: "Column ‘\(column)’ is required but empty")
      case let .invalidNumberInColumn(value, column):
        return String(localized: "Column ‘\(column)’ contains invalid number ‘\(value)’")
      case let .invalidDateInColumn(value, column):
        return String(localized: "Column ‘\(column)’ contains invalid date ‘\(value)’")
      case let .invalidFrequencyInColumn(value, column):
        return String(localized: "Column ‘\(column)’ contains invalid frequency ‘\(value)’")
      case let .invalidGeodesicInColumn(value, column):
        return String(localized: "Column ‘\(column)’ contains invalid geodesic ‘\(value)’")
      case let .conversionErrorInColumn(_, error, column):
        return String(
          localized: "Column ‘\(column)’ contains invalid value: \(String(describing: error))"
        )
      case let .invalidValueInColumn(value, column):
        return String(localized: "Column ‘\(column)’ contains invalid value ‘\(value)’")
      case let .typeMismatch(column, expected, actual):
        return String(
          localized: "Column ‘\(column)’ type mismatch: expected \(expected), got \(actual)"
        )
    }
  }
}
