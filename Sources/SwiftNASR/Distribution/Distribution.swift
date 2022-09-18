import Foundation
import Combine

fileprivate let metatypes = [
    (RecordType.states, State.self),
    (RecordType.airports, Airport.self),
    (RecordType.ARTCCFacilities, ARTCC.self)
] as [(RecordType, Record.Type)]

/// Record types available to load from a distribution.
public enum RecordType: String, Codable {
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
    
    var metatype: Record.Type {
        guard let type = metatypes.first(where: { $0.0 == self })?.1 else {
            preconditionFailure("Unsupported type \(self)")
        }
        return type
   }
    
    static func forType(_ type: Record.Type) -> Self {
        guard let value = metatypes.first(where: { $0.1 == type })?.0 else {
            preconditionFailure("Unsupported type \(type)")
        }
        return value
    }
}

/**
 Protocol that describes classes that can load NASR data from different ways of
 storing distribution data.
 */

public protocol Distribution {
    
    /**
     Locates a file in the distribution by its prefix.
     
     - Parameter prefix: The filename prefix.
     - Returns: The first matching file, or `nil` if no file names match the
                prefix.
     */
    
    func findFile(prefix: String) throws -> String?
    
    /**
     Reads a file from the distribution.
     
     - Parameter path: The path to the file within the distribution.
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     - Parameter eachLine: A callback for each line of text in the file.
     - Parameter data: A line of text from the file being read.
     - Returns: The number of lines in the file.
     
     - Throws: `DistributionError.noSuchFile` if a file at `path` doesn't exist
               within the distribution.
     */
    
    @discardableResult func readFile(path: String, withProgress progressHandler: @escaping (_ progress: Progress) -> Void, eachLine: (_ data: Data) -> Void) throws -> UInt
    
    /**
     Reads a file from the distribution.
     
     - Parameter path: The path to the file within the distribution.
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     - Parameter linesHandler: Called when the number of lines in the file is
                               known.
     - Parameter lines: The number of lines in the file.
     - Returns: A publisher that publishes each line of the file.
     */
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func readFilePublisher(path: String, withProgress progressHandler: @escaping (_ progress: Progress) -> Void, returningLines linesHandler: @escaping (_ lines: UInt) -> Void) -> AnyPublisher<Data, Swift.Error>
    
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
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func readFile(path: String, withProgress progressHandler: @escaping (_ progress: Progress) -> Void, returningLines linesHandler: @escaping (_ lines: UInt) -> Void) -> AsyncThrowingStream<Data, Swift.Error>
}

extension Distribution {
    
    /**
     Synchronously reads the data for a given record type from the distribution.
     
     - Parameter type: The record type to read data for.
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     - Parameter eachRecord: A callback for each data record in the file.
     - Parameter data: The data for an individual record.
     - Returns: The number of lines in the file.
     */
    
    @discardableResult public func read(type: RecordType, withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }, eachRecord: @escaping (_ data: Data) -> Void) throws -> UInt {
        return try readFile(path: "\(type.rawValue).txt", withProgress: progressHandler, eachLine: { data in eachRecord(data) })
    }
    
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
     - Returns: A publisher that publishes each data record from the file.
     */
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func readPublisher(type: RecordType, withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }, returningLines linesHandler: @escaping (_ lines: UInt) -> Void = { _ in }) -> AnyPublisher<Data, Swift.Error> {
        return readFilePublisher(path: "\(type.rawValue).txt", withProgress: progressHandler, returningLines: linesHandler)
    }
    
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
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func read(type: RecordType, withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }, returningLines linesHandler: @escaping (_ lines: UInt) -> Void = { _ in }) -> AsyncThrowingStream<Data, Swift.Error> {
        return readFile(path: "\(type.rawValue).txt", withProgress: progressHandler, returningLines: linesHandler)
    }
}
