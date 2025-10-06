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

public actor NASR {
  let loader: Loader
  var distribution: Distribution?

  /// Aeronautical data is stored into this field once it is parsed. All members
  /// of this instance are `nil` until the ``parse(_:withProgress:errorHandler:)``
  /// function is called for each data type. The ``NASRData`` object can be
  /// serialized to disk using an `Encoder`.
  public var data = NASRData()

  /// Creates a new distribution from a loader.
  public init(loader: Loader) {
    self.loader = loader
  }

  init(data: NASRData) {
    self.data = data
    self.loader = NullLoader()
  }

  /**
   Loads NASR data from a local ZIP file. The file must have already been
   downloaded from the FAA's NASR website.
  
   - Parameter location: The URL for the ZIP file on disk.
   - Returns: The instance for loading, parsing, and accessing that data.
   */

  public static func fromLocalArchive(_ location: URL) -> NASR {
    let loader = ArchiveLoader(location: location)
    return self.init(loader: loader)
  }

  /**
   Loads NASR data from a directory created by unzipping a ZIP file that has
   been downloaded from the FAA's NASR website.
  
   - Parameter location: The URL for the unzipped directory on disk.
   - Returns: The instance for loading, parsing, and accessing that data.
   */

  public static func fromLocalDirectory(_ location: URL, format: DataFormat = .txt) -> NASR {
    let loader = DirectoryLoader(location: location, format: format)
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

  public static func fromInternetToMemory(activeAt date: Date? = nil, format: DataFormat = .txt)
    -> NASR?
  {
    let loader: Loader
    if let date {
      guard let cycle = Cycle.effectiveCycle(for: date) else { return nil }
      loader = ArchiveDataDownloader(cycle: cycle, format: format)
    } else {
      loader = ArchiveDataDownloader(cycle: nil, format: format)
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

  public static func fromInternetToFile(
    _ location: URL? = nil,
    activeAt date: Date? = nil,
    format: DataFormat = .txt
  ) -> NASR? {
    let loader: Loader
    if let date {
      guard let cycle = Cycle.effectiveCycle(for: date) else { return nil }
      loader = ArchiveFileDownloader(cycle: cycle, format: format, location: location)
    } else {
      loader = ArchiveFileDownloader(cycle: nil, format: format, location: location)
    }

    return self.init(loader: loader)
  }

  /**
   Creates an instance for working with NASR data that was parsed and
   serialized at a prior time.
  
   - Parameter data: The deserialized parsed data.
   - Returns: The instance for accessing that data.
   */

  public static func fromData(_ data: NASRData) -> NASR {
    return self.init(data: data)
  }

  /// Sets the distribution directly, useful for testing or when using a custom distribution.
  ///
  /// - Parameter distribution: The distribution to use for parsing.
  public func setDistribution(_ distribution: Distribution) {
    self.distribution = distribution
  }

  /**
   Asynchronously loads data, either from disk or from the Internet.
  
   - Parameter progressHandler: This block is called before processing begins
   with a Progress object that you can use to
   track loading progress. You would add this
   object to your parent Progress object.
   - Parameter result: If successful, contains `Void`. If not, contains the
   error.
   */

  public func load(withProgress progressHandler: @Sendable (Progress) -> Void = { _ in })
    async throws
  {
    distribution = try await loader.load(withProgress: progressHandler)
    let cycle = try await distribution!.readCycle()
    await data.finishParsing(cycle: cycle)
  }

  /**
   Parses data of a certain type (e.g., airports) from the NASR distribution.
   Populates the corresponding field in the ``NASRData`` field of ``data``.
  
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
   - Returns: `true` if the parsing completed, or `false` if it was aborted by
   `errorHandler`.
   */

  @discardableResult
  public func parse(
    _ type: RecordType,
    withProgress progressHandler: @Sendable (Progress) -> Void = { _ in },
    errorHandler: @Sendable (_ error: Swift.Error) -> Bool
  ) async throws -> Bool {
    guard let distribution = self.distribution else { throw Error.notYetLoaded }
    let parser = parserFor(recordType: type, format: distribution.format)
    try await parser.prepare(distribution: distribution)

    let progress = Progress(totalUnitCount: 10)
    progressHandler(progress)
    var parseProgress: Progress!

    let data =
      switch type {
        case .states:
          await distribution.readFile(
            path: "State_&_Country_Codes/STATE.txt",
            withProgress: { readProgress in
              progress.addChild(readProgress, withPendingUnitCount: 1)
            },
            returningLines: { lines in
              parseProgress = Progress(
                totalUnitCount: Int64(lines),
                parent: progress,
                pendingUnitCount: 9
              )
            }
          )
        default:
          await distribution.read(
            type: type,
            withProgress: { readProgress in
              progress.addChild(readProgress, withPendingUnitCount: 1)
            },
            returningLines: { lines in
              parseProgress = Progress(
                totalUnitCount: Int64(lines),
                parent: progress,
                pendingUnitCount: 9
              )
            }
          )
      }

    for try await chunk in data {
      do {
        try await parser.parse(data: chunk)
        parseProgress.completedUnitCount += 1
      } catch {
        let shouldContinue = errorHandler(error)
        if !shouldContinue {
          await parser.finish(data: self.data)
          return false
        }
      }
    }

    await parser.finish(data: self.data)
    return true
  }
}
