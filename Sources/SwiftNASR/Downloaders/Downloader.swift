import Foundation

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
  
   - Returns: The downloaded distribution, and an object for tracking progress.
   - Throws: If the distribution could not be downloaded.
   */

  func load(withProgress progressHandler: @Sendable (Progress) -> Void) async throws -> Distribution
}

@objc
final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
  let progress = Progress(totalUnitCount: 0)

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
    DispatchQueue.main.async { [weak self] in
      self?.progress.completedUnitCount = totalBytesWritten
      self?.progress.totalUnitCount = totalBytesExpectedToWrite
    }
  }
}

private var cycleDateFormatter: DateFormatter {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.dateFormat = "yyyy-MM-dd"
  formatter.timeZone = zulu
  return formatter
}

// swiftlint:disable missing_docs
extension Downloader {
  public var cycleURL: URL {
    switch format {
      case .txt:
        let cycleString = cycleDateFormatter.string(from: cycle.effectiveDate!)
        return URL(
          string:
            "https://nfdc.faa.gov/webContent/28DaySub/28DaySubscription_Effective_\(cycleString).zip"
        )!
      case .csv:
        // CSV format uses DD_Mmm_YYYY format (e.g., 04_Sep_2025_CSV.zip)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "dd_MMM_yyyy"
        let csvDateString = formatter.string(from: cycle.effectiveDate!)
        return URL(
          string: "https://nfdc.faa.gov/webContent/28DaySub/extra/\(csvDateString)_CSV.zip"
        )!
    }
  }

  func load(withProgress progressHandler: @Sendable (Progress) -> Void = { _ in }) throws
    -> Distribution
  {
    progressHandler(completedProgress())
    return NullDistribution()
  }
}
// swiftlint:enable missing_docs
