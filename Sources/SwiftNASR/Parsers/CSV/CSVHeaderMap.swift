import Foundation

/// Maps CSV column names to their indices.
///
/// Built from the header row of a CSV file and shared across all rows.
/// Provides O(1) lookup of column indices by name.
struct CSVHeaderMap: Sendable {
  private let nameToIndex: [String: Int]

  /// All column names in order as they appear in the CSV.
  let columnNames: [String]

  // MARK: - Initializer

  /// Initialize from the header row of a CSV file.
  /// - Parameter headerRow: The first row of the CSV containing column names.
  init(headerRow: [String]) {
    var mapping = [String: Int]()
    var names = [String]()
    for (index, name) in headerRow.enumerated() {
      let normalized = name.trimmingCharacters(in: .whitespaces)
      mapping[normalized] = index
      names.append(normalized)
    }
    self.nameToIndex = mapping
    self.columnNames = names
  }

  // MARK: - Methods

  /// Check if a column exists in this CSV.
  /// - Parameter columnName: The column name to check.
  /// - Returns: True if the column exists.
  func contains(_ columnName: String) -> Bool {
    nameToIndex[columnName] != nil
  }

  /// Validate that all required columns exist.
  /// - Parameter requiredColumns: Array of column names that must be present.
  /// - Throws: `CSVParserError.missingRequiredColumns` if any are missing.
  func validate(requiredColumns: [String]) throws {
    let missing = requiredColumns.filter { nameToIndex[$0] == nil }
    if !missing.isEmpty {
      throw CSVParserError.missingRequiredColumns(missing)
    }
  }

  /// Build an index array for transformer compatibility.
  ///
  /// Returns -1 for columns that don't exist, allowing transformers
  /// to handle missing optional columns gracefully.
  /// - Parameter columnNames: The column names to map.
  /// - Returns: Array of indices (-1 for missing columns).
  func indices(for columnNames: [String]) -> [Int] {
    columnNames.map { nameToIndex[$0] ?? -1 }
  }

  // MARK: - Subscripts

  /// Look up column index by name.
  /// - Parameter columnName: The column name to look up.
  /// - Returns: The index of the column, or nil if not found.
  subscript(_ columnName: String) -> Int? {
    nameToIndex[columnName]
  }
}
