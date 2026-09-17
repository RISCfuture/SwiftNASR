import Foundation

actor ProgressTracker {
  var progress: Progress
  var isStarted = false
  var currentRecordType: String?

  var fractionCompleted: Double { progress.fractionCompleted }

  var isFinished: Bool { isStarted && progress.isFinished }

  init() {
    self.progress = Progress(totalUnitCount: 100)
  }

  func addChild(_ child: Progress, withPendingUnitCount inUnitCount: Int64) {
    self.progress.addChild(child, withPendingUnitCount: inUnitCount)
    isStarted = true
  }

  func setCurrentRecordType(_ recordType: String?) {
    self.currentRecordType = recordType
  }

  func reset(totalUnitCount: Int64) {
    self.progress = Progress(totalUnitCount: totalUnitCount)
    isStarted = false
    currentRecordType = nil
  }
}

// MARK: - Progress Display

/// Whether standard output is a terminal. A redrawing bar is only legible on one; anywhere else it
/// becomes a hundred near-identical log lines, so a plain line per ten percent goes out instead.
let stdoutIsTerminal = isatty(STDOUT_FILENO) == 1

func trackProgress(progress: ProgressTracker) -> Task<Void, any Swift.Error> {
  Task.detached {
    var lastLoggedStep = -1
    repeat {
      try await Task.sleep(for: .seconds(0.1))
      if stdoutIsTerminal {
        await renderProgressBar(progress: progress)
      } else {
        lastLoggedStep = await logProgress(progress: progress, lastLoggedStep: lastLoggedStep)
      }
    } while await !progress.isFinished
  }
}

/// Erases the progress bar's line so what follows prints on a clean one.
func clearProgressLine() {
  guard stdoutIsTerminal else { return }
  print("\r" + String(repeating: " ", count: terminalWidth()) + "\r", terminator: "")
}

/// Prints a line each time progress crosses a ten-percent step, and returns the step it last
/// printed.
private func logProgress(progress: ProgressTracker, lastLoggedStep: Int) async -> Int {
  let fractionCompleted = await progress.fractionCompleted
  let step = Int((max(0.0, min(1.0, fractionCompleted)) * 10).rounded(.down))
  guard step > lastLoggedStep else { return lastLoggedStep }

  let currentRecordType = await progress.currentRecordType
  let statusSuffix = currentRecordType.map { " - parsing \($0)" } ?? ""
  print("  \(step * 10)% complete\(statusSuffix)")
  fflush(nil)
  return step
}

@MainActor
private func renderProgressBar(progress: ProgressTracker) async {
  let fractionCompleted = await progress.fractionCompleted
  let currentRecordType = await progress.currentRecordType
  let percent = Int((fractionCompleted * 100).rounded())

  // Build the status suffix (e.g., " - Parsing airports...")
  let statusSuffix: String
  if let recordType = currentRecordType {
    statusSuffix = " - Parsing \(recordType)..."
  } else {
    statusSuffix = ""
  }

  // Reserve space for percentage, brackets, and status
  let reservedSpace = 10 + statusSuffix.count
  let barWidth = max(terminalWidth() - reservedSpace, 10)  // Ensure minimum bar width

  // Ensure fractionCompleted is within valid bounds
  let clampedFraction = max(0.0, min(1.0, fractionCompleted))
  let completedWidth = Int(clampedFraction * Double(barWidth))

  // Ensure counts are non-negative
  let safeCompletedWidth = max(0, min(barWidth, completedWidth))
  let safeRemainingWidth = max(0, barWidth - safeCompletedWidth)

  let bar =
    String(repeating: "=", count: safeCompletedWidth)
    + String(repeating: " ", count: safeRemainingWidth)
  print("\r[\(bar)] \(percent)%\(statusSuffix)", terminator: "")
  fflush(nil)  // Ensure that all open output streams are flushed immediately
}

private func terminalWidth() -> Int {
  var w = winsize()
  if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w) == 0 {
    return Int(w.ws_col)
  }
  return 80
}
