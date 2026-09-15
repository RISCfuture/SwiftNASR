public import Foundation

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
  let loader: any Loader
  var distribution: (any Distribution)?

  /// Aeronautical data is stored into this field once it is parsed. All members
  /// of this instance are `nil` until the ``parse(_:progress:errorHandler:)``
  /// function is called for each data type. The ``NASRData`` object can be
  /// serialized to disk using an `Encoder`.
  public var data = NASRData()

  /// Creates a new distribution from a loader.
  public init(loader: any Loader) {
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
   - Parameter format: The data format (.txt or .csv). Defaults to .txt.
   - Returns: The instance for loading, parsing, and accessing that data.
   */

  public static func fromLocalArchive(_ location: URL, format: DataFormat = .txt) -> NASR {
    let loader = ArchiveLoader(location: location, format: format)
    return self.init(loader: loader)
  }

  /**
   Loads NASR data from a directory created by unzipping a ZIP file that has
   been downloaded from the FAA's NASR website.

   - Parameter location: The URL for the unzipped directory on disk.
   - Parameter format: The data format (.txt or .csv). Defaults to .txt.
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
   - Parameter format: The data format (.txt or .csv). Defaults to .txt.
   - Returns: The instance for loading, parsing, and accessing that data, or
   nil if no cycle is/was effective for `date`.
   */

  public static func fromInternetToMemory(activeAt date: Date? = nil, format: DataFormat = .txt)
    -> NASR?
  {
    let loader: any Loader
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
   - Parameter format: The data format (.txt or .csv). Defaults to .txt.
   - Returns: The instance for loading, parsing, and accessing that data, or
   nil if no cycle is/was effective for `date`.
   */

  public static func fromInternetToFile(
    _ location: URL? = nil,
    activeAt date: Date? = nil,
    format: DataFormat = .txt
  ) -> NASR? {
    let loader: any Loader
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
  public func setDistribution(_ distribution: any Distribution) {
    self.distribution = distribution
  }

  /**
   Asynchronously loads data, either from disk or from the Internet.

   - Parameter progress: A subprogress, obtained from your own `ProgressManager`, that reports
   loading progress. Pass `nil` to track no progress.
   */

  public func load(progress: consuming Subprogress? = nil) async throws {
    distribution = try await loader.load(progress: progress)
    let cycle = try await distribution!.readCycle()
    await data.finishParsing(cycle: cycle)
  }

  /**
   Parses data of a certain type (e.g., airports) from the NASR distribution.
   Populates the corresponding field in the ``NASRData`` field of ``data``.

   - Parameter type: The type of data to parse.
   - Parameter progress: A subprogress, obtained from your own `ProgressManager`, that reports
   parsing progress. Pass `nil` to track no progress.
   - Parameter errorHandler: Called whenever a parsing problem is encountered.
   Receives a ``RecordParseError`` describing the
   problem, and returns a ``ParseDisposition``:
   `.proceed` to continue parsing, `.abort` to stop.
   - Returns: `true` if parsing completed, or `false` if `errorHandler` returned
   `.abort`.
   */

  @discardableResult
  public func parse(
    _ type: RecordType,
    progress: consuming Subprogress? = nil,
    errorHandler: @Sendable (_ error: RecordParseError) -> ParseDisposition
  ) async throws -> Bool {
    guard let distribution = self.distribution else { throw Error.notYetLoaded }
    let parser = parserFor(recordType: type, format: distribution.format)
    try await parser.prepare(distribution: distribution)

    // Drains diagnostics accumulated by the parser (field errors, and for CSV the
    // per-row record drops). Returns false if the handler asked to abort.
    func drainDiagnostics() async -> Bool {
      guard let diagnosing = parser as? any DiagnosingParser else { return true }
      for event in await diagnosing.takeDiagnostics() where errorHandler(event) == .abort {
        return false
      }
      return true
    }

    // Discards diagnostics accumulated for a record that ended up being dropped.
    func discardPendingDiagnostics() async {
      guard let diagnosing = parser as? any DiagnosingParser else { return }
      _ = await diagnosing.takeDiagnostics()
    }

    if parser is any CSVParser {
      let readProgress = progress?.start(totalCount: 1)

      let data = await distribution.read(type: type)
      for try await chunk in data {
        do {
          try await parser.parse(data: chunk)
        } catch {
          await discardPendingDiagnostics()
          if errorHandler(.fromThrown(recordType: type, recordID: nil, error)) == .abort {
            await parser.finish(data: self.data)
            return false
          }
          continue
        }
        if await drainDiagnostics() == false {
          await parser.finish(data: self.data)
          return false
        }
      }

      readProgress?.complete(count: 1)
      await parser.finish(data: self.data)
      return true
    }

    // The fixed-width path reads the record file, then parses it line by line: one tenth of the
    // work is the read, the rest the parse.
    let recordProgress = progress?.start(totalCount: 10)
    var parseProgress: ProgressManager?

    let data =
      switch type {
        case .states:
          await distribution.readFile(
            path: "State_&_Country_Codes/STATE.txt",
            progress: recordProgress?.subprogress(assigningCount: 1),
            returningLines: { lines in
              parseProgress = recordProgress?.subprogress(assigningCount: 9)
                .start(totalCount: Int(lines))
            }
          )
        default:
          await distribution.read(
            type: type,
            progress: recordProgress?.subprogress(assigningCount: 1),
            returningLines: { lines in
              parseProgress = recordProgress?.subprogress(assigningCount: 9)
                .start(totalCount: Int(lines))
            }
          )
      }

    for try await chunk in data {
      defer { parseProgress?.complete(count: 1) }
      do {
        try await parser.parse(data: chunk)
      } catch {
        await discardPendingDiagnostics()
        if errorHandler(.fromThrown(recordType: type, recordID: nil, error)) == .abort {
          await parser.finish(data: self.data)
          return false
        }
        continue
      }
      if await drainDiagnostics() == false {
        await parser.finish(data: self.data)
        return false
      }
    }

    await parser.finish(data: self.data)
    return true
  }
}
