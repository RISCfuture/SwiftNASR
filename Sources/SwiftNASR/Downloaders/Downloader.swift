import Foundation
import Combine
import Dispatch

/**
 A downloader is a class that can download a NASR distribution from the FAA's
 website. This abstract superclass contains functionality common to all
 downloaders.
 */

open class Downloader: Loader {
    
    /// The distribution cycle.
    public let cycle: Cycle
    
    /// The queue that progress updates are processed on. By default, an
    /// internal queue at the `userInteractive` QoS level. If you have a main
    /// thread where progress updates must be made, then set this var to that
    /// thread.
    public static var progressQueue = DispatchQueue(label: "codes.tim.SwiftNASR.Downloader.progress", qos: .userInteractive)

    private static var cycleDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = zulu
        return formatter
    }
    
    /// The URL to download the NASR data from, given `cycle`.
    public var cycleURL: URL {
        let cycleString = Downloader.cycleDateFormatter.string(from: cycle.date!)
        return URL(string: "https://nfdc.faa.gov/webContent/28DaySub/28DaySubscription_Effective_\(cycleString).zip")!
    }

    /**
     Creates a downloader for a given cycle.
     
     - Parameter cycle: The cycle to download NASR data for. If not specified,
                        uses the current cycle.
     */
    
    public init(cycle: Cycle? = nil) {
        if let cycle = cycle { self.cycle = cycle }
        else { self.cycle = Cycle.current }
    }
    
    /**
     Downloads the NASR data asynchronously.
     
     - Parameter callback: A function to call with the completed download.
     - Parameter result: If successful, cointains the distribution. If not,
                         contains the error.
     - Returns: A progress value that is updated during the download.
     */

    open func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, callback: @escaping (_ result: Result<Distribution, Swift.Error>) -> Void) {
        progressHandler(completedProgress())
    }
    
    /**
     Downloads the NASR data asynchronously.
     
     - Returns: A publisher that publishes the downloaded distribution.
     */
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    open func loadPublisher(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) -> AnyPublisher<Distribution, Swift.Error> {
        progressHandler(completedProgress())
        return Empty(completeImmediately: true).eraseToAnyPublisher()
    }
    
    /**
     Downloads the NASR data asynchronously.
     
     - Returns: The downloaded distribution, and an object for tracking progress.
     - Throws: If the distribution could not be downloaded.
     */
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    open func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) async throws -> Distribution {
        progressHandler(completedProgress())
        return NullDistribution()
    }
    
    @objc class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
        var progress = Progress(totalUnitCount: 0)
        
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            // noop
        }
        
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            progress.completedUnitCount = totalBytesWritten
            progress.totalUnitCount = totalBytesExpectedToWrite
        }
    }
}
