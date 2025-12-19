import Foundation

actor ErrorCollector {
  private var errors: [RecordError] = []

  var errorCount: Int {
    errors.count
  }

  func record(_ error: Swift.Error, recordType: String) {
    errors.append(RecordError(recordType: recordType, error: error))
  }

  func errorsByRecordType() -> [String: [RecordError]] {
    Dictionary(grouping: errors, by: \.recordType)
  }

  func printSummary(verbose: Bool, formatName: String) {
    guard !errors.isEmpty else {
      print("\n\(formatName) - No parsing errors")
      return
    }

    if verbose {
      print("\n=== All Errors (\(formatName)) ===")
      for error in errors {
        print("[\(error.recordType)] \(error.error)")
      }
    } else {
      print("\n=== Error Summary (\(formatName)) ===")
      print("Total errors: \(errors.count)")

      let grouped = errorsByRecordType()
      let sortedTypes = grouped.keys.sorted { grouped[$0]!.count > grouped[$1]!.count }

      for recordType in sortedTypes {
        let typeErrors = grouped[recordType]!
        print("\n\(recordType) (\(typeErrors.count) error\(typeErrors.count == 1 ? "" : "s")):")
        let samplesToShow = min(3, typeErrors.count)
        for i in 0..<samplesToShow {
          print("  - \(typeErrors[i].error)")
        }
        if typeErrors.count > samplesToShow {
          print("  ... and \(typeErrors.count - samplesToShow) more")
        }
      }
    }
  }

  struct RecordError {
    let recordType: String
    let error: Swift.Error
  }
}
