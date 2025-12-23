import Foundation

/// A single row from a CSV file with header-based field access.
///
/// Provides type-safe access to CSV fields by column name rather than
/// numeric index, making parsers resilient to column order changes.
struct CSVRow: Sendable {
  /// The header-to-index mapping (shared across all rows in a file).
  let headerMap: CSVHeaderMap

  /// The raw field values for this row.
  let values: [String]

  /// Number of fields in this row.
  var count: Int { values.count }

  // MARK: - Methods

  /// Access a field that should exist but may be empty.
  ///
  /// Use this for columns that are in the schema but may have blank values.
  ///
  /// - Parameter columnName: The name of the column to access.
  /// - Returns: The trimmed value if non-empty, nil if empty.
  /// - Throws: `CSVParserError.unknownColumn` if column doesn't exist.
  func optional(_ columnName: String) throws -> String? {
    let value = try self[columnName]
    return value.isEmpty ? nil : value
  }

  // MARK: - Subscripts

  /// Access a field by column name.
  ///
  /// - Parameter columnName: The name of the column to access.
  /// - Returns: The trimmed string value at that column.
  /// - Throws: `CSVParserError.unknownColumn` if column doesn't exist,
  ///           `CSVParserError.columnIndexOutOfBounds` if row is truncated.
  subscript(_ columnName: String) -> String {
    get throws {
      guard let index = headerMap[columnName] else {
        throw CSVParserError.unknownColumn(columnName, available: headerMap.columnNames)
      }
      guard index < values.count else {
        throw CSVParserError.columnIndexOutOfBounds(
          column: columnName,
          index: index,
          rowFieldCount: values.count
        )
      }
      return values[index].trimmingCharacters(in: .whitespaces)
    }
  }

  /// Access a field that may not exist in the CSV schema.
  ///
  /// Use this for columns that are truly optional - they may not be
  /// present in the CSV file at all.
  ///
  /// - Parameter columnName: The name of the column to access.
  /// - Returns: The trimmed value if column exists and has data, nil otherwise.
  subscript(ifExists columnName: String) -> String? {
    guard let index = headerMap[columnName], index < values.count else {
      return nil
    }
    let value = values[index].trimmingCharacters(in: .whitespaces)
    return value.isEmpty ? nil : value
  }
}
