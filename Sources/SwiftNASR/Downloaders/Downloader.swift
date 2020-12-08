import Foundation
import Dispatch

/**
 A downloader is a class that can download a NASR distribution from the FAA's
 website. This abstract superclass contains functionality common to all
 downloaders.
 */

open class Downloader: Loader {
    
    /// The distribution cycle.
    public let cycle: Cycle

    private static var cycleDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
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
     */

    public func load(callback: @escaping (_ result: Result<Distribution, Swift.Error>) -> Void) {}
    
    /// Errors that can occur when working with distributions.
    public enum Error: Swift.Error, CustomStringConvertible {
        
        /**
         Received a bad HTTP response.
         
         - Parameter response: The HTTP response.
         */
        
        case badResponse(_ response: HTTPURLResponse)
        
        /// Downloaded tempfile unexpectedly missing.
        case noFile
        
        /// Response did not contain any body.
        case noData
        
        /// Response body was not parseable.
        case badData
        
        public var description: String {
            switch self {
                case .badResponse(let response):
                    return "Bad response: \(response.statusCode)"
                case .noFile:
                    return "Couldn't find file to load"
                case .noData:
                    return "No data was downloaded"
                case .badData:
                    return "Data is invalid"
            }
        }
    }
}
