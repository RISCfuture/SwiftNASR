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
  var CSVDirectory: URL { get set }

  /// The CSV files this parser will process.
  var CSVFiles: [String] { get }

  /// Progress object for reporting parsing progress.
  var progress: Progress? { get set }

  /// Cumulative bytes read across all files (for progress tracking).
  var bytesRead: Int64 { get set }
}

extension CSVParser {
  /// Calculates total bytes for all CSV files this parser will process.
  func calculateTotalBytes() -> Int64 {
    CSVFiles.reduce(0) { total, filename in
      let fileURL = CSVDirectory.appendingPathComponent(filename)
      if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
        let size = attrs[.size] as? Int64
      {
        return total + size
      }
      return total
    }
  }

  /// Sets up progress tracking and returns the Progress object.
  /// Call this after prepare() and before parsing.
  func setupProgress() -> Progress {
    let prog = Progress(totalUnitCount: calculateTotalBytes())
    progress = prog
    bytesRead = 0
    return prog
  }

  /// Helper method to parse a CSV file using raw string arrays.
  func parseCSVFile(
    filename: String,
    expectedFieldCount: Int,
    handler: ([String]) async throws -> Void
  ) async throws {
    let fileURL = CSVDirectory.appendingPathComponent(filename)

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw ParserError.badData("CSV file not found: \(filename)")
    }

    let reader = try StreamingCSVReader(url: fileURL)
    _ = try await reader.readRow()  // Skip header row

    while let row = try await reader.readRow() {
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

      // Update cumulative progress
      if let progress = self.progress {
        let currentFileBytes = await reader.bytesRead
        progress.completedUnitCount = bytesRead + currentFileBytes
      }
    }

    // Add this file's total bytes to cumulative count
    if let fileBytes = await reader.totalBytes {
      bytesRead += fileBytes
      progress?.completedUnitCount = bytesRead
    }
  }
}
