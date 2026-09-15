public import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/**
 A downloader is a class that can download a NASR distribution from the FAA's
 website. This abstract superclass contains functionality common to all
 downloaders.
 */

public protocol Downloader: Loader {

  /// The distribution cycle.
  var cycle: Cycle { get }

  /// The data format to download (TXT or CSV).
  var format: DataFormat { get }

  /// The URL to download the NASR data from, given ``cycle``.
  var cycleURL: URL { get }

  /**
   Creates a downloader for a given cycle.

   - Parameter cycle: The cycle to download NASR data for. If not specified,
                      uses the current cycle.
   - Parameter format: The data format to download (defaults to .txt).
   */

  init(cycle: Cycle?, format: DataFormat)

  /**
   Downloads the NASR data asynchronously.

   - Parameter progress: A subprogress, obtained from your own `ProgressManager`, that reports
                         download progress. Pass `nil` to track no progress.
   - Returns: The downloaded distribution.
   - Throws: If the distribution could not be downloaded.
   */

  func load(progress: consuming Subprogress?) async throws -> any Distribution
}

#if canImport(Darwin)
  @objc
#endif
final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
  private let progress: ByteReadProgress

  init(progress: consuming Subprogress?) {
    self.progress = ByteReadProgress(progress)
    super.init()
  }

  func urlSession(
    _: URLSession,
    downloadTask _: URLSessionDownloadTask,
    didFinishDownloadingTo _: URL
  ) {
    // noop
  }

  func urlSession(
    _: URLSession,
    downloadTask _: URLSessionDownloadTask,
    didWriteData _: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    progress.update(
      completed: Int(clamping: totalBytesWritten),
      total: Int(clamping: totalBytesExpectedToWrite)
    )
  }
}

/// Formats the cycle effective date the way the TXT distribution URL spells it (e.g. `2025-09-04`).
private let TXTCycleDateStyle = Date.VerbatimFormatStyle(
  format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
  locale: Locale(identifier: "en_US_POSIX"),
  timeZone: zulu,
  calendar: Calendar(identifier: .gregorian)
)

/// Formats the cycle effective date the way the CSV distribution URL spells it (e.g. `04_Sep_2025`).
private let CSVCycleDateStyle = Date.VerbatimFormatStyle(
  format: "\(day: .twoDigits)_\(month: .abbreviated)_\(year: .defaultDigits)",
  locale: Locale(identifier: "en_US"),
  timeZone: zulu,
  calendar: Calendar(identifier: .gregorian)
)

// swiftlint:disable missing_docs
extension Downloader {
  public var cycleURL: URL {
    switch format {
      case .txt:
        let cycleString = TXTCycleDateStyle.format(cycle.effectiveDate!)
        return URL(
          string:
            "https://nfdc.faa.gov/webContent/28DaySub/28DaySubscription_Effective_\(cycleString).zip"
        )!
      case .csv:
        let cycleString = CSVCycleDateStyle.format(cycle.effectiveDate!)
        return URL(
          string: "https://nfdc.faa.gov/webContent/28DaySub/extra/\(cycleString)_CSV.zip"
        )!
    }
  }

  // periphery:ignore - default protocol implementation; always provided by conformers
  func load(progress: consuming Subprogress? = nil) throws -> any Distribution {
    completeImmediately(progress)
    return NullDistribution()
  }
}
// swiftlint:enable missing_docs
