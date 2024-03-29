import Foundation

let zulu = TimeZone(secondsFromGMT: 0)!

/**
 The `NASR` class provides top-level access to loading, parsing, and accessing
 aeronautical data disseminated via NASR distributions.
 
 To use this class, you must first create an instance, use that instance to load
 the NASR data (from the Internet or locally), parse the data, and then you can
 access it. See the documentation overview for basic information on how to use
 this class to load, parse, and access aeronautical data.
 
 The `NASR` class provides a number of different static methods you can use to
 load and parse NASR data. Parsing is computationally intensive, so it is
 recommended to do it only once. See the documentation overview or the
 documentation for ``NASRData`` for information on how to serialize parsed data
 to storage for more efficient retrieval.
 */

public final class NASR {
    
    /// The queue that progress updates are processed on. By default, an
    /// internal queue at the `userInteractive` QoS level. If you have a main
    /// thread where progress updates must be made, then set this var to that
    /// thread.
    public static var progressQueue = DispatchQueue(label: "codes.tim.SwiftNASR.progress", qos: .userInteractive)
    
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
     of this instance are `nil` until the
     ``parse(_:withProgress:errorHandler:completionHandler:)`` function is
     called for each data type. The ``NASRData`` object can be serialized to
     disk using an `Encoder`.
     */
    public var data = NASRData()

    public required init(loader: Loader) {
        self.loader = loader
    }
    
    /**
     Asynchronously loads data, either from disk or from the Internet.
     
     There is another variation of this method that uses a Combine publisher
     (``NASR/loadPublisher(withProgress:)``) and one that uses `async`/`await`
     (``NASR/load(withProgress:)``).
     
     - Parameter progressHandler: This block is called before processing begins
                                  with a Progress object that you can use to
                                  track loading progress. You would add this
                                  object to your parent Progress object.
     - Parameter callback: A block to call when the data is loaded.
     - Parameter result: If successful, contains `Void`. If not, contains the
                         error.
     */

    public func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, callback: @escaping (_ result: Result<Void, Swift.Error>) -> Void) {
        loader.load(withProgress: progressHandler) { result in
            switch result {
            case let .success(distribution):
                self.distribution = distribution
                do {
                    try distribution.readCycle { cycle in
                        self.data.cycle = cycle
                        callback(.success(()))
                    }
                } catch (let error) {
                    callback(.failure(error))
                }
            case let .failure(error):
                callback(.failure(error))
            }
        }
    }
    
    /**
     Parses data of a certain type (e.g., airports) from the NASR distribution.
     Populates the corresponding field in the ``NASRData`` field of ``data``.
     
     There are other variations of this method that use Combine publishers
     (e.g., ``NASR/parseAirportsPublisher(errorHandler:withProgress:)``) or
     `async`/`await` (e.g., ``NASR/parseAirports(withProgress:errorHandler:)``).
     
     - Parameter type: The type of data to parse.
     - Parameter progressHandler: This block is called before processing begins
                                  with a Progress object that you can use to
                                  track loading progress. You would add this
                                  object to your parent Progress object.
     - Parameter errorHandler: A block of code to call if parsing fails. If the
                               block returns `true`, parsing will continue even
                               if a specific record has an error. If not given,
                               any error will be swallowed but parsing will
                               continue.
     - Parameter error: The parsing error that occurred.
     */
    
    public func parse(_ type: RecordType,
                      withProgress progressHandler: @escaping (Progress) -> Void = { _ in },
                      errorHandler: @escaping (_ error: Swift.Error) -> Bool,
                      completionHandler: @escaping () -> Void) throws {
        guard let distribution = self.distribution else {
            throw Error.notYetLoaded
        }
        
        let parser = parserFor(recordType: type)
        
        try parse(parser: parser, processor: { process in
            switch type {
                case .states:
                    try distribution.readFile(path: "State_&_Country_Codes/STATE.txt", withProgress: progressHandler) { data in
                        process(data)
                    }
                default:
                    try distribution.read(type: type, withProgress: progressHandler) { data in
                        process(data)
                    }
            }
            completionHandler()
        }, errorHandler: errorHandler)
    }
    
    private func parse(parser: Parser,
                       processor: @escaping (@escaping (Data) -> Void) throws -> Void,
                       errorHandler: @escaping (Swift.Error) -> Bool) throws {
        guard let distribution = self.distribution else {
            throw Error.notYetLoaded
        }

        parser.prepare(distribution: distribution) { result in
            switch result {
            case .success(_):
                do {
                    try processor() { recordData in
                        do {
                            try parser.parse(data: recordData)
                        } catch (let e) {
                            let shouldContinue = errorHandler(e)
                            if !shouldContinue { return }
                        }
                    }
                } catch (let error) {
                    let shouldContinue = errorHandler(error)
                    if !shouldContinue { return }
                }
                
                parser.finish(data: self.data)
            case let .failure(error):
                let shouldContinue = errorHandler(error)
                if !shouldContinue { return }
            }
        }
    }
}
