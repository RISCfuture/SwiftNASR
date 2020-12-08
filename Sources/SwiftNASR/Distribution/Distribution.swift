import Foundation

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
     Reads a file from the distribution.
     
     - Parameter path: The path to the file within the distribution.
     - Parameter eachLine: A callback for each line of text in the file.
     - Parameter data: A line of text from the file being read.
     
     - Throws: `DistributionError.noSuchFile` if a file at `path` doesn't exist
               within the distribution.
     */
    
    func readFile(path: String, eachLine: (_ data: Data) -> Void) throws
}

extension Distribution {
    
    /**
     Reads the data for a given record type from the distribution.
     
     - Parameter type: The record type to read data for.
     - Parameter eachRecord: A callback for each data record in the file.
     - Parameter data: The data for an individual record.
     */
    
    public func read(type: RecordType, eachRecord: (_ data: Data) -> Void) throws {
        try readFile(path: "\(type.rawValue).txt", eachLine: eachRecord)
    }
}

/// Errors that can occur when working with distributions.
public enum DistributionError: Swift.Error, CustomStringConvertible {
    
    /**
     Tried to read from a file that doesn't exist within a distribution.
     
     - Parameter path: The path to the nonexistent file.
     */
    case noSuchFile(path: String)
    
    public var description: String {
        switch self {
            case .noSuchFile(let path):
                return "No such file \(path)"
        }
    }
}
