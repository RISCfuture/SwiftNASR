import Foundation
import StreamingCSV

/**
 Base protocol for parsers that handle CSV-formatted NASR data.

 CSV parsers read comma-separated value files from the FAA's NASR distribution.
 Unlike the fixed-width text format, CSV files have header rows and use commas
 to separate fields.
 */
public protocol CSVParser: Parser {
  /// The distribution to read CSV files from.
  var distribution: (any Distribution)? { get set }

  /// The CSV files this parser will process.
  var CSVFiles: [String] { get }

  /// Progress object for reporting parsing progress.
  var progress: Progress? { get set }

  /// Cumulative bytes read across all files (for progress tracking).
  var bytesRead: Int64 { get set }
}

extension CSVParser {
  /// Sets up progress tracking and returns the Progress object.
  func setupProgress() -> Progress {
    let prog = Progress(totalUnitCount: 1)
    progress = prog
    bytesRead = 0
    return prog
  }

  /// Helper method to parse a CSV file using raw string arrays.
  /// Streams data directly from the distribution using true streaming (no buffering).
  func parseCSVFile(
    filename: String,
    expectedFieldCount: Int,
    handler: ([String]) async throws -> Void
  ) async throws {
    guard let distribution else {
      throw ParserError.badData("Distribution not set for CSV parser")
    }

    let dataStream = await distribution.readFileRaw(path: filename) { _ in }

    // Use true streaming - rows are parsed as data arrives
    let rowStream = StreamingCSVReader.stream(from: dataStream)

    var isFirstRow = true
    for try await rowBytes in rowStream {
      // Skip header row
      if isFirstRow {
        isFirstRow = false
        continue
      }

      let row = rowBytes.stringFields

      // More flexible field count validation
      // Allow rows with fewer fields if they're mostly empty at the end
      // or rows with slightly more fields (might have extra commas)
      if row.count < expectedFieldCount - 5 || row.count > expectedFieldCount + 5 {
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

      try await handler(adjustedRow)
    }
  }
}
