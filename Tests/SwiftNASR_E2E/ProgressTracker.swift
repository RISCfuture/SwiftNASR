import Foundation
import Observation
import Synchronization

/// Root progress for one format's load-and-parse run, plus the label shown beside the bar.
final class ProgressTracker: Sendable {

  /// The progress every load and parse reports into. Hand out `subprogress(assigningCount:)` to
  /// give a phase its share of the run.
  let manager: ProgressManager

  private let recordType = Mutex<String?>(nil)

  /// The record type currently being parsed, if any.
  var currentRecordType: String? { recordType.withLock { $0 } }

  init(totalCount: Int) {
    manager = ProgressManager(totalCount: totalCount)
  }

  func setCurrentRecordType(_ recordType: String?) {
    self.recordType.withLock { $0 = recordType }
  }
}

// MARK: - Progress Display

/// Draws a progress bar for `tracker`, redrawing each time its completed percentage changes and
/// stopping once its progress finishes.
///
/// `ProgressManager` is `Observable`, so the bar follows the run's actual progress rather than a
/// timer.
func trackProgress(progress tracker: ProgressTracker) -> Task<Void, Never> {
  let manager = tracker.manager
  return Task {
    var lastPercent = -1
    let percentages = Observations<Int, Never>.untilFinished {
      manager.isFinished ? .finish : .next(percentComplete(of: manager))
    }
    for await percent in percentages where percent != lastPercent {
      lastPercent = percent
      await renderProgressBar(percent: percent, recordType: tracker.currentRecordType)
    }
    if manager.isFinished { await renderProgressBar(percent: 100, recordType: nil) }
  }
}

private func percentComplete(of manager: ProgressManager) -> Int {
  let clampedFraction = max(0, min(1, manager.fractionCompleted))
  return Int((clampedFraction * 100).rounded())
}

@MainActor
func renderProgressBar(percent: Int, recordType: String?) {
  // Build the status suffix (e.g., " - Parsing airports...")
  let statusSuffix = recordType.map { " - Parsing \($0)..." } ?? ""

  // Reserve space for percentage, brackets, and status
  let reservedSpace = 10 + statusSuffix.count
  let barWidth = max(terminalWidth() - reservedSpace, 10)  // Ensure minimum bar width

  let completedWidth = max(0, min(barWidth, barWidth * percent / 100))
  let bar =
    String(repeating: "=", count: completedWidth)
    + String(repeating: " ", count: barWidth - completedWidth)
  print("\r[\(bar)] \(percent)%\(statusSuffix)", terminator: "")
  fflush(nil)  // Ensure that all open output streams are flushed immediately
}

func terminalWidth() -> Int {
  var w = winsize()
  if unsafe ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w) == 0 {
    return Int(w.ws_col)
  }
  return 80
}
