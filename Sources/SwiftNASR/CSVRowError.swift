public import Foundation

/// A CSV row that couldn't be turned into a record, and where to find it.
///
/// Carried as the `underlying` error of a
/// ``RecordParseError/recordError(recordType:recordID:underlying:)`` when a CSV
/// row is dropped. Parsing continues with the next row.
public struct CSVRowError: Swift.Error, Sendable {

  /// The CSV file containing the row (e.g., `FIX_BASE.csv`).
  public let filename: String

  /// The row's position in the file, counting the header row as row 1.
  public let rowNumber: UInt

  /// Why the row was dropped.
  public let reason: Reason

  /// Why a CSV row was dropped.
  public enum Reason: Sendable {

    /// The row has fewer fields than the file's header row.
    case truncated(fieldCount: UInt, expectedFieldCount: UInt)

    /// The row's values couldn't be parsed into a record.
    case invalid(any Swift.Error & Sendable)
  }
}

extension CSVRowError: LocalizedError {
  public var errorDescription: String? {
    String(localized: "Couldn’t parse a CSV row.")
  }

  public var failureReason: String? {
    let row = String(rowNumber)
    switch reason {
      case let .truncated(fieldCount, expectedFieldCount):
        return String(
          localized:
            "Row \(row) of \(filename) has \(fieldCount) of \(expectedFieldCount) fields."
        )
      case let .invalid(underlying):
        return String(
          localized:
            "Row \(row) of \(filename): \(String(describing: underlying))"
        )
    }
  }
}

extension CSVRowError: CustomStringConvertible {
  public var description: String { failureReason ?? "" }
}
