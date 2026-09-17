import Foundation
import Synchronization
import SwiftNASR

/// How many errors of each kind one record type produced, with a few sample messages of each.
struct ErrorTally: Sendable {
  var droppedRecordCount = 0
  var fieldErrorCount = 0
  var droppedRecordSamples: [String] = []
  var fieldErrorSamples: [String] = []
}

/// Tallies the parse errors every record type's error handler reports.
///
/// Recording is synchronous because the error handler is: hopping onto an actor lets the run finish
/// and the summary print while the last errors are still queued, which makes the counts vary from
/// run to run.
final class ErrorCollector: Sendable {
  private let sampleLimit: Int
  private let tallies = Mutex<[RecordType: ErrorTally]>([:])

  /// Every record type that reported an error, with its tally.
  var talliesByRecordType: [RecordType: ErrorTally] { tallies.withLock { $0 } }

  init(sampleLimit: Int) {
    self.sampleLimit = sampleLimit
  }

  func record(_ error: RecordParseError) {
    tallies.withLock { tallies in
      var tally = tallies[error.recordType, default: ErrorTally()]
      switch error {
        case .recordError:
          tally.droppedRecordCount += 1
          append(error, to: &tally.droppedRecordSamples)
        case .fieldError:
          tally.fieldErrorCount += 1
          append(error, to: &tally.fieldErrorSamples)
      }
      tallies[error.recordType] = tally
    }
  }

  private func append(_ error: RecordParseError, to samples: inout [String]) {
    guard samples.count < sampleLimit else { return }
    samples.append(error.localizedDescription)
  }
}

extension RecordParseError {
  /// The record type the error was reported against.
  var recordType: RecordType {
    switch self {
      case let .recordError(recordType, _, _): recordType
      case let .fieldError(recordType, _, _, _, _): recordType
    }
  }
}
