import Foundation
import StreamingCSV

/**
 Base protocol for parsers that handle CSV-formatted NASR data.

 CSV parsers read comma-separated value files from the FAA's NASR distribution.
 Unlike the fixed-width text format, CSV files have header rows and use commas
 to separate fields.
 */
public protocol CSVParser: Parser {
  /// The directory containing CSV files for this record type.
  var csvDirectory: URL { get set }
}

extension CSVParser {
  /// Helper method to parse a CSV file using raw string arrays
  func parseCSVFile(
    filename: String,
    expectedFieldCount: Int,
    handler: ([String]) async throws -> Void
  ) async throws {
    let fileURL = csvDirectory.appendingPathComponent(filename)

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw ParserError.badData("CSV file not found: \(filename)")
    }

    let reader = try StreamingCSVReader(url: fileURL)
    _ = try await reader.readRow()  // Skip header row

    var rowCount = 0
    var skippedCount = 0
    var processedCount = 0

    while let row = try await reader.readRow() {
      rowCount += 1

      // More flexible field count validation
      // Allow rows with fewer fields if they're mostly empty at the end
      // or rows with slightly more fields (might have extra commas)
      if row.count < expectedFieldCount - 5 || row.count > expectedFieldCount + 5 {
        skippedCount += 1
        // Skip rows with field count mismatches
        continue
      }

      // Pad or trim the row to expected field count
      var adjustedRow = row
      if row.count < expectedFieldCount {
        // Pad with empty strings
        adjustedRow.append(contentsOf: Array(repeating: "", count: expectedFieldCount - row.count))
      } else if row.count > expectedFieldCount {
        // Trim extra fields
        adjustedRow = Array(row.prefix(expectedFieldCount))
      }

      processedCount += 1
      try await handler(adjustedRow)
    }
  }
}
