import Foundation

/// A Standard Terminal Arrival (STAR) or Standard Instrument Departure Procedure (DP).
///
/// These procedures define point-to-point paths from/to the enroute airspace system
/// to/from adapted airports. Each procedure consists of a main body (or multiple bodies)
/// and optional transitions.
public struct DepartureArrivalProcedure: Record, Identifiable {

  // MARK: - Properties

  /// The type of procedure (STAR or DP).
  public let procedureType: ProcedureType

  /// Internal sequence number grouping records for this procedure.
  public let sequenceNumber: String

  /// FAA-assigned computer identifier for the procedure.
  /// Example: "GLAND.BLUMS5" for a STAR, "CATH4.PSP" for a DP.
  /// May be "NOT ASSIGNED" for procedures without a computer code.
  public let computerCode: String?

  /// The name of the procedure.
  /// Example: "BLUMS FIVE" for a STAR, "CATHEDRAL FOUR" for a DP.
  public let name: String?

  /// The points that make up this procedure's path.
  public internal(set) var points = [Point]()

  /// Airports adapted to use this procedure.
  public internal(set) var adaptedAirports = [AdaptedAirport]()

  /// Transitions for this procedure.
  public internal(set) var transitions = [Transition]()

  public var id: String { "\(procedureType.rawValue)\(sequenceNumber)" }

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  // MARK: - Types

  /// The type of procedure.
  public enum ProcedureType: String, RecordEnum {
    /// Standard Terminal Arrival (STAR)
    case STAR = "S"

    /// Standard Instrument Departure Procedure (DP)
    case DP = "D"
  }

  /// Type of fix or facility in a procedure point.
  public enum FixType: String, RecordEnum {
    /// Adapted airport
    case adaptedAirport = "AA"

    /// Break in route
    case breakInRoute = "B"

    /// Coordinated fix
    case coordinatedFix = "C"

    /// Computer navigation fix
    case computerNavigationFix = "CN"

    /// Distance measuring equipment
    case DME = "D"

    /// Entry (ARTCC)
    case entry = "E"

    /// Bearing intersection
    case bearingIntersection = "I"

    /// Air routes bearing intersection
    case airRoutesBearingIntersection = "IB"

    /// Segment bearing intersection
    case segmentBearingIntersection = "IS"

    /// Navaid - Airport (for DP: indicates airport served by DP but not by any body)
    case navaidAirport = "NA"

    /// Navaid - VOR with DME
    case navaidVOR_DME = "ND"

    /// Navaid - DME only
    case navaidDMEOnly = "NO"

    /// Navaid - VOR
    case navaidVOR = "NV"

    /// Navaid - VORTAC
    case navaidVORTAC = "NW"

    /// Navaid - RBN
    case navaidRBN = "NX"

    /// Navaid - TACAN
    case navaidTACAN = "NT"

    /// Navaid - ILS
    case navaidILS = "NZ"

    /// Navaid - LFR
    case navaidLFR = "N7"

    /// Navaid - VHF RBN
    case navaidVHF_RBN1 = "N8"

    /// Navaid - VHF RBN (alternate)
    case navaidVHF_RBN2 = "N9"

    /// Waypoint
    case waypoint = "P"

    /// Reporting point
    case reportingPoint = "R"

    /// Start STAR/DP departing
    case startDeparting = "SS"

    /// Start STAR/DP transition
    case startTransition = "ST"

    /// Turning point
    case turningPoint = "T"

    /// Turning point (alternate)
    case turningPointA = "TA"

    /// Turning point (alternate 2)
    case turningPointP = "TP"

    /// Training point
    case trainingPoint = "TT"

    /// ARTCC boundary point
    case ARTCCBoundaryPoint = "U"

    /// Airway crossing
    case airwayCrossing = "XA"

    /// Transition crossing
    case transitionCrossing = "XT"

    /// ARTCC boundary crossing
    case ARTCCBoundaryCrossing = "Z"
  }

  // MARK: - Nested Types

  /// A point along the procedure path.
  public struct Point: Record {
    /// Type of fix or facility at this point.
    public let fixType: FixType

    /// Geographic position.
    ///
    /// This is available when parsing from TXT format but not from CSV format.
    /// For CSV-parsed data, use the identifier to look up the position from
    /// the corresponding fix, navaid, or airport records.
    public let position: Location?

    /// Fix/navaid/airport identifier.
    public let identifier: String

    /// ICAO region code (for fixes only).
    public let ICAORegionCode: String?

    /// Airways or navaids using this numbered fix.
    public let airwaysNavaids: String?

    public enum CodingKeys: String, CodingKey {
      case fixType, position, identifier, ICAORegionCode, airwaysNavaids
    }
  }

  /// An airport adapted to use this procedure.
  public struct AdaptedAirport: Record {
    /// Geographic position.
    ///
    /// This is available when parsing from TXT format but not from CSV format.
    /// For CSV-parsed data, use the identifier to look up the position from
    /// the airport records.
    public let position: Location?

    /// Airport identifier.
    public let identifier: String

    /// Runway end identifier (e.g., "08", "26L", "ALL").
    ///
    /// Only available when parsing from CSV format. When "ALL", the procedure
    /// applies to all runways at this airport.
    public let runwayEndID: String?

    public enum CodingKeys: String, CodingKey {
      case position, identifier, runwayEndID
    }
  }

  /// A transition from/to the enroute airspace system.
  public struct Transition: Record {
    /// Computer code for this transition.
    /// Example: "AUS.BLUMS5" for STAR, "CATH4.PDZ" for DP.
    public let computerCode: String?

    /// Name of the transition.
    /// Example: "AUSTIN", "PARADISE"
    public let name: String?

    /// Points along the transition path.
    public internal(set) var points = [Point]()

    public enum CodingKeys: String, CodingKey {
      case computerCode, name, points
    }
  }

  public enum CodingKeys: String, CodingKey {
    case procedureType, sequenceNumber, computerCode, name
    case points, adaptedAirports, transitions
  }
}
