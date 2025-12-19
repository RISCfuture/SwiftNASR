import Foundation

private let metatypes =
  [
    (RecordType.states, State.self),
    (RecordType.airports, Airport.self),
    (RecordType.ARTCCFacilities, ARTCC.self),
    (RecordType.reportingPoints, Fix.self),
    (RecordType.weatherReportingStations, WeatherStation.self),
    (RecordType.airways, Airway.self),
    (RecordType.ILSes, ILS.self),
    (RecordType.terminalCommFacilities, TerminalCommFacility.self),
    (RecordType.departureArrivalProceduresComplete, DepartureArrivalProcedure.self),
    (RecordType.preferredRoutes, PreferredRoute.self),
    (RecordType.holds, Hold.self),
    (RecordType.weatherReportingLocations, WeatherReportingLocation.self),
    (RecordType.parachuteJumpAreas, ParachuteJumpArea.self),
    (RecordType.militaryTrainingRoutes, MilitaryTrainingRoute.self),
    (RecordType.codedDepartureRoutes, CodedDepartureRoute.self),
    (RecordType.miscActivityAreas, MiscActivityArea.self),
    (RecordType.ARTCCBoundarySegments, ARTCCBoundarySegment.self),
    (RecordType.FSSCommFacilities, FSSCommFacility.self),
    (RecordType.ATSAirways, ATSAirway.self),
    (RecordType.locationIdentifiers, LocationIdentifier.self)
  ] as [(RecordType, any Record.Type)]

/// Record types available to load from a distribution.
public enum RecordType: String, Codable, Sendable {
  case ARTCCFacilities = "AFF"
  case airports = "APT"
  case ARTCCBoundarySegments = "ARB"
  case ATSAirways = "ATS"
  case weatherReportingStations = "AWOS"
  case airways = "AWY"
  case codedDepartureRoutes = "CDR"
  case FSSCommFacilities = "COM"
  case reportingPoints = "FIX"
  case flightServiceStations = "FSS"
  case holds = "HPF"
  case ILSes = "ILS"
  case locationIdentifiers = "LID"
  case miscActivityAreas = "MAA"
  case militaryTrainingRoutes = "MTR"
  case navaids = "NAV"
  case preferredRoutes = "PFR"
  case parachuteJumpAreas = "PJA"
  case departureArrivalProceduresComplete = "STARDP"
  case terminalCommFacilities = "TWR"
  case weatherReportingLocations = "WXL"

  /// This is a pseudo-record-type intended to represent the `STATE.txt` file.
  /// `states` is not a loadable record type.
  case states = "_ST"

  var metatype: any Record.Type {
    guard let type = metatypes.first(where: { $0.0 == self })?.1 else {
      preconditionFailure("Unsupported type \(self)")
    }
    return type
  }

  static func forType(_ type: any Record.Type) -> Self {
    guard let value = metatypes.first(where: { $0.1 == type })?.0 else {
      preconditionFailure("Unsupported type \(type)")
    }
    return value
  }
}

/// Global actor that guarantees exclusive access to the distribution file.
@globalActor public actor FileReadActor: GlobalActor {
  public static let shared = FileReadActor()

  private init() {}
}

/**
 Protocol that describes classes that can load NASR data from different ways of
 storing distribution data.
 */

public protocol Distribution: Sendable {

  /// The data format (TXT or CSV) for this distribution.
  ///
  /// This property determines which parsers are used when calling
  /// ``NASR/parse(_:withProgress:errorHandler:)``. TXT format uses fixed-width
  /// parsers, while CSV format uses comma-separated value parsers.
  var format: DataFormat { get }

  /**
   Locates a file in the distribution by its prefix.
  
   - Parameter prefix: The filename prefix.
   - Returns: The first matching file, or `nil` if no file names match the
              prefix.
   */

  func findFile(prefix: String) throws -> String?

  /**
   Decompresses and reads a file asynchronously from a distribution.
  
   - Parameter path: The path to the file.
   - Parameter progressHandler: A block that receives the Progress object when
                                the task begins. You can add it to your parent
                                Progress.
   - Parameter linesHandler: Called when the number of lines in the file is
                             known.
   - Returns: An `AsyncStream` that contains each line, in order, from the
   file.
   */

  @FileReadActor
  func readFile(
    path: String,
    withProgress progressHandler: @Sendable (_ progress: Progress) -> Void,
    returningLines linesHandler: (_ lines: UInt) -> Void
  ) -> AsyncThrowingStream<Data, Swift.Error>

  /**
   Reads the cycle from the distribution.
  
   - Returns: The parsed cycle, or `nil` if the cycle could not be parsed.
   */
  func readCycle() async throws -> Cycle?
}

extension Distribution {

  /**
   Reads the data for a given record type from the distribution.
  
   - Parameter type: The record type to read data for.
   - Parameter progressHandler: A block that receives the Progress object when
   the task begins. You can add it to your parent Progress.
   - Parameter linesHandler: Called when the number of lines in the file is
   known.
   - Returns: An async stream of data from the record file, and the progress
   through that file.
   */

  @FileReadActor
  public func read(
    type: RecordType,
    withProgress progressHandler: @Sendable (_ progress: Progress) -> Void = { _ in },
    returningLines linesHandler: (_ lines: UInt) -> Void = { _ in }
  ) -> AsyncThrowingStream<Data, Swift.Error> {
    switch format {
      case .txt:
        return readFile(
          path: "\(type.rawValue).txt",
          withProgress: progressHandler,
          returningLines: linesHandler
        )
      case .csv:
        // For CSV format, we need to handle multiple files per record type
        return readCSVFiles(for: type, withProgress: progressHandler, returningLines: linesHandler)
    }
  }

  /// Reads CSV files for a given record type
  @FileReadActor
  public func readCSVFiles(
    for type: RecordType,
    withProgress progressHandler: @Sendable (_ progress: Progress) -> Void = { _ in },
    returningLines linesHandler: (_ lines: UInt) -> Void = { _ in }
  ) -> AsyncThrowingStream<Data, Swift.Error> {
    // For CSV format, the actual parsing happens in the CSV parsers which read files directly
    // We just need to check if the record type is supported
    switch type {
      case .airports, .navaids, .flightServiceStations, .ARTCCFacilities, .reportingPoints,
        .weatherReportingStations, .airways, .ILSes, .terminalCommFacilities, .codedDepartureRoutes:
        break  // These types are supported for CSV
      default:
        // For unsupported types, return empty stream
        return AsyncThrowingStream { continuation in
          continuation.finish()
        }
    }

    // For CSV, we'll just return a marker indicating CSV format
    // The actual parsing happens in the CSV parsers which read files directly
    // Report a completed progress for the "read" phase since CSV files are read all at once
    let readProgress = Progress(totalUnitCount: 1)
    readProgress.completedUnitCount = 1
    progressHandler(readProgress)

    // Call the lines handler with 1 to ensure parseProgress is initialized
    linesHandler(1)
    return AsyncThrowingStream { continuation in
      continuation.yield(Data("CSV".utf8))
      continuation.finish()
    }
  }
}
