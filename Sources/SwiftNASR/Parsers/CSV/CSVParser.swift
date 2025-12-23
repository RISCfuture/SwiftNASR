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

  /// Parse a CSV file with header-based row access.
  ///
  /// This method reads the header row to build a column name to index mapping,
  /// then provides each data row as a `CSVRow` with named field access.
  ///
  /// - Parameters:
  ///   - filename: The CSV file to parse.
  ///   - requiredColumns: Column names that must exist (validated before parsing rows).
  ///   - handler: Closure receiving each data row as a `CSVRow`.
  /// - Throws: `CSVParserError.missingRequiredColumns` if required columns are missing.
  func parseCSVFile(
    filename: String,
    requiredColumns: [String] = [],
    handler: (CSVRow) async throws -> Void
  ) async throws {
    guard let distribution else {
      throw ParserError.badData("Distribution not set for CSV parser")
    }

    let dataStream = await distribution.readFileRaw(path: filename) { _ in }
    // FAA data files use Latin-1 (ISO-8859-1) encoding for special characters like degree symbols
    let rowStream = StreamingCSVReader.stream(from: dataStream, encoding: .isoLatin1)

    var headerMap: CSVHeaderMap?

    for try await rowBytes in rowStream {
      let row = rowBytes.stringFields

      // First row is the header
      if headerMap == nil {
        headerMap = CSVHeaderMap(headerRow: row)
        try headerMap!.validate(requiredColumns: requiredColumns)
        continue
      }

      // Skip empty rows (e.g., trailing blank lines)
      if row.isEmpty || (row.count == 1 && row[0].isEmpty) {
        continue
      }

      // Skip rows with fewer fields than the header (truncated rows)
      if row.count < headerMap!.columnNames.count {
        continue
      }

      let csvRow = CSVRow(headerMap: headerMap!, values: row)
      try await handler(csvRow)
    }
  }
}
