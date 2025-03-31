import Foundation

private let metatypes = [
    (RecordType.states, State.self),
    (RecordType.airports, Airport.self),
    (RecordType.ARTCCFacilities, ARTCC.self)
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
    case HARFixes = "HARFIX"
    case holds = "HPF"
    case ILSes = "ILS"
    case locationIdentifiers = "LID"
    case miscActivityAreas = "MAA"
    case militaryTrainingRoutes = "MTR"
    case enrouteFixes = "NATFIX"
    case navaids = "NAV"
    case preferredRoutes = "PFR"
    case parachuteJumpAreas = "PJA"
    case departureArrivalProcedures = "SSD"
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
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     - Parameter linesHandler: Called when the number of lines in the file is
                               known.
     - Parameter lines: The number of lines in the file.
     - Returns: An `AsyncStream` that contains each line, in order, from the
     file.
     */

    @FileReadActor
    func readFile(path: String, withProgress progressHandler: @Sendable (_ progress: Progress) -> Void, returningLines linesHandler: (_ lines: UInt) -> Void) -> AsyncThrowingStream<Data, Swift.Error>
}

public extension Distribution {

    /**
     Reads the data for a given record type from the distribution.

     - Parameter type: The record type to read data for.
     - Parameter progressHandler: A block that receives the Progress object when
     the task begins.
     - Parameter progress: A child Progress object you can add to your parent
     Progress.
     - Parameter linesHandler: Called when the number of lines in the file is
     known.
     - Parameter lines: The number of lines in the file.
     - Returns: An async stream of data from the record file, and the progress
     through that file.
     */

    @FileReadActor
    func read(type: RecordType, withProgress progressHandler: @Sendable (_ progress: Progress) -> Void = { _ in }, returningLines linesHandler: (_ lines: UInt) -> Void = { _ in }) -> AsyncThrowingStream<Data, Swift.Error> {
        return readFile(path: "\(type.rawValue).txt", withProgress: progressHandler, returningLines: linesHandler)
    }
}
