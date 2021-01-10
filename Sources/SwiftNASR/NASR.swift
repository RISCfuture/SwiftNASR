import Foundation

let zulu = TimeZone(secondsFromGMT: 0)!

/**
 The `SwiftNASR` class provides top-level access to loading, parsing, and
 accessing aeronautical data disseminated via NASR distributions. To use this
 class, you must first create an instance, use that instance to load the NASR
 data (from the Internet or locally), parse the data, and then you can access
 it. See the `README.md` file for basic information on how to use this class to
 load, parse, and access aeronautical data.
 
 The `SwiftNASR` class provides a number of different static methods you can use
 to load and parse NASR data. Parsing is computationally intensive, so it is
 recommended to do it only once. See `README.md` or the documentation for the
 `NASRData` for information on how to serialize parsed data to storage for more
 efficient retrieval.
 */

public final class NASR {
    
    /**
     Loads NASR data from a local ZIP file. The file must have already been
     downloaded from the FAA's NASR website.
     
     - Parameter location: The URL for the ZIP file on disk.
     - Returns: The instance for loading, parsing, and accessing that data.
     */
    
    public class func fromLocalArchive(_ location: URL) -> NASR {
        let loader = ArchiveLoader(location: location)
        return self.init(loader: loader)
    }
    
    /**
     Loads NASR data from a directory created by unzipping a ZIP file that has
     been downloaded from the FAA's NASR website.
     
     - Parameter location: The URL for the unzipped directory on disk.
     - Returns: The instance for loading, parsing, and accessing that data.
     */

    public class func fromLocalDirectory(_ location: URL) -> NASR {
        let loader = DirectoryLoader(location: location)
        return self.init(loader: loader)
    }
    
    /**
     Loads NASR data from the FAA website. The data is downloaded into memory
     and not saved to a file.
     
     - Parameter date: The date to use for determining the data cycle. The data
                       downloaded will be the data active during `date`. If not
                       given, the current data is used.
     - Returns: The instance for loading, parsing, and accessing that data, or
                nil if no cycle is/was effective for `date`.
     */

    public class func fromInternetToMemory(activeAt date: Date? = nil) -> NASR? {
        let loader: Loader
        if let date = date {
            guard let cycle = Cycle.effectiveCycle(for: date) else { return nil }
            loader = ArchiveDataDownloader(cycle: cycle)
        } else {
            loader = ArchiveDataDownloader()
        }

        return self.init(loader: loader)
    }
    
    /**
     Loads NASR data from the FAA website. The data is downloaded to a ZIP file
     on disk.
     
     - Parameter location: The location on disk to save the ZIP file. If not
                           given, a tempfile is created.
     - Parameter date: The date to use for determining the data cycle. The data
                       downloaded will be the data active during `date`. If not
                       given, the current data is used.
     - Returns: The instance for loading, parsing, and accessing that data, or
                nil if no cycle is/was effective for `date`.
     */

    public class func fromInternetToFile(_ location: URL? = nil, activeAt date: Date? = nil) -> NASR? {
        let loader: Loader
        if let date = date {
            guard let cycle = Cycle.effectiveCycle(for: date) else { return nil }
            loader = ArchiveFileDownloader(cycle: cycle, location: location)
        } else {
            loader = ArchiveFileDownloader(location: location)
        }

        return self.init(loader: loader)
    }
    
    /**
     Creates an instance for working with NASR data that was parsed and
     serialized at a prior time.
     
     - Parameter data: The deserialized parsed data.
     - Returns: The instance for accessing that data.
     */
    
    public class func fromData(_ data: NASRData) -> NASR {
        let NASR = self.init(loader: NullLoader())
        NASR.data = data
        return NASR
    }

    let loader: Loader
    var distribution: Distribution? = nil

    /**
     Aeronautical data is stored into this field once it is parsed. All members
     of this instance are `nil` until the `parse` function is called for each
     data type. The `data` object can be serialized to disk using an `Encoder`.
     */
    public var data = NASRData()

    internal required init(loader: Loader) {
        self.loader = loader
    }
    
    /**
     Asynchronously loads data, either from disk or from the Internet.
     
     - Parameter callback: A block to call when the data is loaded.
     - Parameter result: If successful, contains `Void`. If not, contains the
                         error.
     */

    public func load(callback: @escaping (_ result: Result<Void, Swift.Error>) -> Void) {
        loader.load { result in
            switch result {
            case .success(let distribution):
                self.distribution = distribution
                do {
                    try distribution.readCycle { cycle in
                        self.data.cycle = cycle
                        callback(.success(()))
                    }
                } catch (let error) {
                    callback(.failure(error))
                }
            case .failure(let error):
                callback(.failure(error))
            }
        }
    }
    
    /**
     Parses data of a certain type (e.g., airports) from the NASR distribution.
     Populates the corresponding field in the `data` field of this instance.
     
     - Parameter type: The type of data to parse.
     - Parameter errorHandler: A block of code to call if parsing fails. If the
                               block returns `true`, parsing will continue even
                               if a specific record has an error. If not given,
                               any error will be swallowed but parsing will
                               continue.
     - Parameter error: The parsing error that occurred.
     */
    
    public func parse(_ type: RecordType,
                      errorHandler: @escaping (_ error: Swift.Error) -> Bool) throws {
        guard let distribution = self.distribution else {
            throw Error.notYetLoaded
        }
        
        let parser = parserFor(recordType: type)
        
        try parse(parser: parser, processor: { process in
            switch type {
                case .states:
                    try distribution.readFile(path: "State_&_Country_Codes/STATE.txt") { process($0) }
                default:
                    try distribution.read(type: type) { process($0) }
            }
        }, errorHandler: errorHandler)
    }
    
    private func parse(parser: Parser,
                       processor: @escaping (@escaping (Data) -> Void) throws -> Void,
                       errorHandler: @escaping (Swift.Error) -> Bool) throws {
        guard let distribution = self.distribution else {
            throw Error.notYetLoaded
        }

        try parser.prepare(distribution: distribution)

        try processor() { recordData in
            do {
                try parser.parse(data: recordData)
            } catch (let e) {
                let shouldContinue = errorHandler(e)
                if !shouldContinue { return }
            }
        }

        parser.finish(data: data)
    }
    
    /// Errors that can occur when working with this class.
    public enum Error: Swift.Error, CustomStringConvertible {
        /// `parse` was called before `load`.
        case notYetLoaded
        
        public var description: String {
            switch self {
                case .notYetLoaded:
                    return "This NASR has not been loaded yet"
            }
        }
    }
}
