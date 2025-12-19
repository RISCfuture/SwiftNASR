import Foundation
@preconcurrency import RegexBuilder

public protocol Parser: Actor {
  func prepare(distribution: Distribution) async throws

  func parse(data: Data) async throws

  func finish(data: NASRData) async
}

final class OffsetParser: Sendable {
  private let distanceRef = Reference<UInt?>()
  private let directionRef = Reference<Offset.Direction>()
  private var rx: some RegexComponent {
    Regex {
      Anchor.startOfSubject
      Capture(as: distanceRef) {
        Optionally { OneOrMore(.digit) }
      } transform: {
        .init($0)
      }
      Capture(as: directionRef) {
        Optionally {
          ChoiceOf {
            "L"
            "R"
            "L/R"
            "B"
          }
        }
      } transform: {
        .from(string: String($0)) ?? .both
      }
      Anchor.endOfSubject
    }
  }

  func parse(_ string: String) throws -> Offset? {
    guard let match = try rx.regex.wholeMatch(in: string) else { return nil }
    let distance = match[distanceRef]
    let direction = match[directionRef]
    guard let distance else { return .init(distanceFt: 0, direction: .both) }
    return .init(distanceFt: distance, direction: direction)
  }
}

extension Parser {
  static func raw<T: RecordEnum>(_ rawValue: T.RawValue, toEnum _: T.Type) throws -> T {
    guard let val = T.for(rawValue) else {
      throw ParserError.unknownRecordEnumValue(rawValue)
    }
    return val
  }
}

enum ParserError: Swift.Error, CustomStringConvertible {
  case badData(_ reason: String)
  case unknownRecordIdentifier(_ recordIdentifier: String)
  case unknownRecordEnumValue(_ value: Sendable)
  case invalidValue(_ value: Sendable)
  case truncatedRecord(recordType: String, expectedMinLength: Int, actualLength: Int)
  case missingRequiredField(field: String, recordType: String)
  case invalidLocation(latitude: Float?, longitude: Float?, context: String)
  case unknownParentRecord(parentType: String, parentID: String, childType: String)
  case invalidSequenceNumber(_ value: String, recordType: String)

  var description: String {
    switch self {
      case .badData(let reason):
        return "Invalid data: \(reason)"
      case .unknownRecordIdentifier(let identifier):
        return "Unknown record identifier '\(identifier)'"
      case .unknownRecordEnumValue(let value):
        return "Unknown record value '\(value)'"
      case .invalidValue(let value):
        return "Invalid value '\(value)'"
      case let .truncatedRecord(recordType, expected, actual):
        return
          "Truncated \(recordType) record: expected at least \(expected) characters, got \(actual)"
      case let .missingRequiredField(field, recordType):
        return "Missing required field '\(field)' in \(recordType) record"
      case let .invalidLocation(latitude, longitude, context):
        return
          "Invalid location (lat: \(latitude.map { String($0) } ?? "nil"), lon: \(longitude.map { String($0) } ?? "nil")) in \(context)"
      case let .unknownParentRecord(parentType, parentID, childType):
        return "\(childType) record references unknown \(parentType) '\(parentID)'"
      case let .invalidSequenceNumber(value, recordType):
        return "Invalid sequence number '\(value)' in \(recordType) record"
    }
  }
}

func parserFor(recordType: RecordType, format: DataFormat = .txt) -> Parser {
  switch format {
    case .txt:
      switch recordType {
        case .airports:
          return FixedWidthAirportParser()
        case .states: return StateParser()
        case .ARTCCFacilities:
          return FixedWidthARTCCParser()
        case .flightServiceStations: return FixedWidthFSSParser()
        case .navaids: return FixedWidthNavaidParser()
        case .reportingPoints: return FixedWidthFixParser()
        case .weatherReportingStations: return FixedWidthWeatherStationParser()
        case .airways: return FixedWidthAirwayParser()
        case .ILSes: return FixedWidthILSParser()
        case .terminalCommFacilities: return FixedWidthTerminalCommFacilityParser()
        case .departureArrivalProceduresComplete:
          return FixedWidthDepartureArrivalProcedureCompleteParser()
        case .preferredRoutes: return FixedWidthPreferredRouteParser()
        case .holds: return FixedWidthHoldParser()
        case .weatherReportingLocations: return FixedWidthWeatherReportingLocationParser()
        case .parachuteJumpAreas: return FixedWidthParachuteJumpAreaParser()
        case .militaryTrainingRoutes: return FixedWidthMilitaryTrainingRouteParser()
        case .miscActivityAreas: return FixedWidthMiscActivityAreaParser()
        case .ARTCCBoundarySegments: return FixedWidthARTCCBoundarySegmentParser()
        case .FSSCommFacilities: return FixedWidthFSSCommFacilityParser()
        case .ATSAirways: return FixedWidthATSAirwayParser()
        case .locationIdentifiers: return FixedWidthLocationIdentifierParser()
        default:
          preconditionFailure("No TXT parser for \(recordType)")
      }
    case .csv:
      switch recordType {
        case .airports:
          return CSVAirportParser()
        case .ARTCCFacilities:
          return CSVARTCCParser()
        case .flightServiceStations: return CSVFSSParser()
        case .navaids: return CSVNavaidParser()
        case .reportingPoints: return CSVFixParser()
        case .weatherReportingStations: return CSVWeatherStationParser()
        case .airways: return CSVAirwayParser()
        case .ILSes: return CSVILSParser()
        case .terminalCommFacilities: return CSVTerminalCommFacilityParser()
        case .codedDepartureRoutes: return CSVCodedDepartureRouteParser()
        default:
          preconditionFailure("No CSV parser for \(recordType)")
      }
  }
}
