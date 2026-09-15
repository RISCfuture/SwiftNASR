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

/// Whether standard output is a terminal. A redrawing bar is only legible on one; anywhere else it
/// becomes a hundred near-identical log lines, so a plain line per ten percent goes out instead.
let stdoutIsTerminal = isatty(STDOUT_FILENO) == 1

/// Reports the progress of `tracker`, stopping once its progress finishes.
///
/// `ProgressManager` is `Observable`, so this follows the run's actual progress rather than a
/// timer.
func trackProgress(progress tracker: ProgressTracker) -> Task<Void, Never> {
  let manager = tracker.manager
  // Off a terminal there is no bar to redraw, so only every tenth percent is worth a line.
  let step = stdoutIsTerminal ? 1 : 10
  return Task {
    var lastReported = -1
    let percentages = Observations<Int, Never>.untilFinished {
      manager.isFinished ? .finish : .next(percentComplete(of: manager))
    }
    for await percent in percentages where percent / step != lastReported {
      lastReported = percent / step
      await reportProgress(percent: percent, recordType: tracker.currentRecordType)
    }
    if manager.isFinished, stdoutIsTerminal {
      await renderProgressBar(percent: 100, recordType: nil)
    }
  }
}

/// Erases the progress bar's line so what follows prints on a clean one.
func clearProgressLine() {
  guard stdoutIsTerminal else { return }
  print("\r" + String(repeating: " ", count: terminalWidth()) + "\r", terminator: "")
}

private func percentComplete(of manager: ProgressManager) -> Int {
  let clampedFraction = max(0, min(1, manager.fractionCompleted))
  return Int((clampedFraction * 100).rounded())
}

@MainActor
private func reportProgress(percent: Int, recordType: String?) {
  guard stdoutIsTerminal else {
    let statusSuffix = recordType.map { " - parsing \($0)" } ?? ""
    print("  \(percent)% complete\(statusSuffix)")
    fflush(nil)
    return
  }
  renderProgressBar(percent: percent, recordType: recordType)
}

@MainActor
private func renderProgressBar(percent: Int, recordType: String?) {
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

private func terminalWidth() -> Int {
  var w = winsize()
  if unsafe ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w) == 0 {
    return Int(w.ws_col)
  }
  return 80
}
