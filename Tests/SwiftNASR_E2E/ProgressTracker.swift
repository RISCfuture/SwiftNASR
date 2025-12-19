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

func trackProgress(progress: ProgressTracker) -> Task<Void, Swift.Error> {
  Task.detached {
    repeat {
      try await Task.sleep(for: .seconds(0.1))
      await renderProgressBar(progress: progress)
    } while await !progress.isFinished
  }
}

@MainActor
func renderProgressBar(progress: ProgressTracker, barWidth: Int = 80) async {
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
  fflush(stdout)  // Ensure that the output is flushed immediately
}

func terminalWidth() -> Int {
  var w = winsize()
  if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 {
    return Int(w.ws_col)
  }
  return 80
}
