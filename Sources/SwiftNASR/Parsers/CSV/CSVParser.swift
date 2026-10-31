internal import Foundation
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
}

/// A ``CSVParser`` that drops a row it can't parse, reports it through
/// ``DiagnosingParser``, and continues with the next row.
protocol DiagnosingCSVParser: CSVParser, DiagnosingParser {
  /// Columns whose values identify the record a row belongs to, in the order
  /// they appear in a dropped row's record ID. Columns absent from a file are
  /// skipped.
  static var identityColumns: [String] { get }
}

extension DiagnosingCSVParser {
  /// Parse a CSV file with header-based row access.
  ///
  /// This method reads the header row to build a column name to index mapping,
  /// then provides each data row as a `CSVRow` with named field access. A row
  /// that is truncated, or that `handler` throws on, is recorded as a dropped
  /// row and parsing continues.
  ///
  /// - Parameters:
  ///   - filename: The CSV file to parse.
  ///   - requiredColumns: Column names that must exist (validated before parsing rows).
  ///   - handler: Closure receiving each data row as a `CSVRow`.
  /// - Throws: `CSVParserError.missingRequiredColumns` if required columns are
  ///   missing, any error reading the file, or `CancellationError` if the task
  ///   is cancelled.
  func parseCSVFile(
    filename: String,
    requiredColumns: [String] = [],
    handler: (CSVRow) async throws -> Void
  ) async throws {
    guard let distribution else {
      throw ParserError.badData("Distribution not set for CSV parser")
    }

    let dataStream = await distribution.readFileRaw(path: filename, progress: nil)
    // FAA data files use Latin-1 (ISO-8859-1) encoding for special characters like degree symbols
    let rowStream = StreamingCSVReader.stream(from: dataStream, encoding: .isoLatin1)

    var headerMap: CSVHeaderMap?
    var rowNumber: UInt = 0

    for try await rowBytes in rowStream {
      try Task.checkCancellation()
      rowNumber += 1
      let fields = rowBytes.stringFields

      guard let headerMap else {
        let header = CSVHeaderMap(headerRow: fields)
        try header.validate(requiredColumns: requiredColumns)
        headerMap = header
        continue
      }
      if isBlank(fields) { continue }

      let row = CSVRow(headerMap: headerMap, values: fields)
      func drop(_ reason: CSVRowError.Reason) {
        recordDroppedRow(
          CSVRowError(filename: filename, rowNumber: rowNumber, reason: reason),
          id: identity(of: row)
        )
      }

      if row.isTruncated {
        drop(.truncated(fieldCount: row.fieldCount, expectedFieldCount: row.expectedFieldCount))
        continue
      }
      let diagnosticCount = pendingDiagnostics.count
      do {
        try await handler(row)
      } catch let error as CancellationError {
        throw error
      } catch {
        pendingDiagnostics.removeSubrange(diagnosticCount...)
        drop(.invalid(RecordParseError.sendable(error)))
      }
    }
  }

  private func isBlank(_ fields: [String]) -> Bool {
    fields.isEmpty || (fields.count == 1 && fields[0].isEmpty)
  }

  private func identity(of row: CSVRow) -> String? {
    let values = Self.identityColumns.compactMap { row[ifExists: $0] }
    return values.isEmpty ? nil : values.joined(separator: "/")
  }
}
