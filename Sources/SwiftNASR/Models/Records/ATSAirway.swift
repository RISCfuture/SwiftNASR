import Foundation

/// An Air Traffic Service (ATS) route/airway.
///
/// ATS routes include Atlantic routes (AT), Bahama routes (BF), Pacific routes (PA),
/// and Puerto Rico routes (PR). These routes consist of individual points with
/// associated navigation and altitude information.
public struct ATSAirway: Record, Identifiable {

  // MARK: - Identification

  /// The airway designation (AT, BF, PA, PR)
  public let designation: Designation

  /// The airway identifier (e.g., "A1", "B1")
  public let airwayIdentifier: String

  /// Whether this is an RNAV route
  public let isRNAV: Bool

  /// The airway type (Alaska, Hawaii, or general)
  public let airwayType: AirwayType

  /// Unique identifier combining designation and airway ID
  public var id: String {
    "\(designation.rawValue)\(airwayIdentifier)\(isRNAV ? "R" : "")\(airwayType.rawValue)"
  }

  /// Chart/publication effective date
  public let effectiveDateComponents: DateComponents

  // MARK: - Route Points

  /// The points along the airway
  public internal(set) var routePoints: [RoutePoint]

  // MARK: - Route Remarks (from RMK)

  /// General remarks about the entire route
  public internal(set) var routeRemarks: [String]

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  // MARK: - Types

  /// The ATS airway designation type
  public enum Designation: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable, Sendable
  {
    case atlantic = "AT"
    case bahama = "BF"
    case pacific = "PA"
    case puertoRico = "PR"

    public var description: String {
      switch self {
        case .atlantic: return "Atlantic Route"
        case .bahama: return "Bahama Route"
        case .pacific: return "Pacific Route"
        case .puertoRico: return "Puerto Rico Route"
      }
    }
  }

  /// The ATS airway type (regional)
  public enum AirwayType: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable, Sendable {
    case alaska = "A"
    case hawaii = "H"
    case general = ""

    public var description: String {
      switch self {
        case .alaska: return "Alaska Specific"
        case .hawaii: return "Hawaii Specific"
        case .general: return "General"
      }
    }
  }

  /// The type of point on the airway (navaid type or waypoint)
  public enum PointType: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable, Sendable {
    case waypoint = "WAY-PT"
    case reportingPoint = "REP-PT"
    case VOR_DME = "VOR/DME"
    case VORTAC = "VORTAC"
    case NDB_DME = "NDB/DME"
    case NDB = "NDB"
    case VOR = "VOR"
    case DME = "DME"
    case canadian = "CN"

    public var description: String {
      switch self {
        case .waypoint: return "Waypoint"
        case .reportingPoint: return "Reporting Point"
        case .VOR_DME: return "VOR/DME"
        case .VORTAC: return "VORTAC"
        case .NDB_DME: return "NDB/DME"
        case .NDB: return "NDB"
        case .VOR: return "VOR"
        case .DME: return "DME"
        case .canadian: return "Canadian"
      }
    }
  }

  /// A point along the ATS airway
  public struct RoutePoint: Record, Equatable, Hashable, Codable, Sendable {
    /// The sequence number of this point along the airway
    public let sequenceNumber: UInt

    /// The name of the navaid/fix at this point
    public let pointName: String?

    /// The type of the navaid/fix at this point.
    public let pointType: PointType?

    /// Whether this is a named fix for publication purposes
    public let isNamedFix: Bool

    /// The state postal code of the point
    public let stateCode: String?

    /// The ICAO region code
    public let ICAORegionCode: String?

    /// The position of the point.
    public let position: Location?

    /// The minimum reception altitude (MRA) for fixes (feet).
    public let minimumReceptionAltitudeFt: UInt?

    /// The navaid identifier
    public let navaidIdentifier: String?

    // MARK: - Segment Data (from ATS1)

    /// Track angle outbound (RNAV)
    public let trackAngleOutbound: TrackAnglePair?

    /// Distance to changeover point (nautical miles; RNAV).
    public let distanceToChangeoverPointNM: UInt?

    /// Track angle inbound (RNAV)
    public let trackAngleInbound: TrackAnglePair?

    /// Distance to next point (nautical miles).
    public let distanceToNextPointNM: Double?

    /// Segment magnetic course.
    public let magneticCourse: Bearing<Double>?

    /// Segment magnetic course opposite direction.
    public let magneticCourseOpposite: Bearing<Double>?

    /// Minimum enroute altitude (feet).
    public let minimumEnrouteAltitudeFt: UInt?

    /// MEA direction.
    public let MEADirection: BoundDirection?

    /// MEA opposite direction altitude (feet).
    public let MEAOppositeAltitudeFt: UInt?

    /// MEA opposite direction.
    public let MEAOppositeDirection: BoundDirection?

    /// Maximum authorized altitude (feet).
    public let maximumAuthorizedAltitudeFt: UInt?

    /// Minimum obstruction clearance altitude (feet).
    public let minimumObstructionClearanceAltitudeFt: UInt?

    /// Whether the airway has a gap at this point
    public let hasAirwayGap: Bool?

    /// Distance to changeover point for next navaid (nautical miles).
    public let changeoverPointDistanceNM: UInt?

    /// Minimum crossing altitude (feet).
    public let minimumCrossingAltitudeFt: UInt?

    /// Direction of crossing.
    public let crossingDirection: BoundDirection?

    /// Minimum crossing altitude opposite direction (feet).
    public let crossingAltitudeOppositeFt: UInt?

    /// Direction of crossing opposite.
    public let crossingDirectionOpposite: BoundDirection?

    /// Gap in signal coverage indicator
    public let hasSignalGap: Bool?

    /// US airspace only indicator
    public let usAirspaceOnly: Bool?

    /// The variation between magnetic and true north (degrees; positive is east).
    public let magneticVariationDeg: Int?

    /// ARTCC identifier
    public let ARTCCIdentifier: String?

    /// GNSS MEA (feet).
    public let GNSS_MEAFt: UInt?

    /// GNSS MEA direction.
    public let GNSS_MEADirection: BoundDirection?

    /// GNSS MEA opposite altitude (feet).
    public let GNSS_MEAOppositeFt: UInt?

    /// GNSS MEA opposite direction.
    public let GNSS_MEAOppositeDirection: BoundDirection?

    /// DME/DME/IRU MEA (feet).
    public let DME_DME_IRU_MEAFt: UInt?

    /// DME/DME/IRU MEA direction.
    public let DME_DME_IRU_MEADirection: BoundDirection?

    /// DME/DME/IRU MEA opposite altitude (feet).
    public let DME_DME_IRU_MEAOppositeFt: UInt?

    /// DME/DME/IRU MEA opposite direction.
    public let DME_DME_IRU_MEAOppositeDirection: BoundDirection?

    /// Whether this is a dogleg (turn point not at a navaid)
    public let isDogleg: Bool?

    /// Required Navigation Performance (RNP) in nautical miles.
    public let RNP_NM: Double?

    // MARK: - Changeover Point Data (from ATS3)

    /// Changeover navaid name
    public internal(set) var changeoverNavaidName: String?

    /// Changeover navaid type
    public internal(set) var changeoverNavaidType: PointType?

    /// Changeover navaid state code
    public internal(set) var changeoverNavaidStateCode: String?

    /// Changeover navaid position.
    public internal(set) var changeoverNavaidPosition: Location?

    // MARK: - Remarks (from ATS4)

    /// Point-specific remarks
    public internal(set) var remarks: [String]

    // MARK: - Changeover Exceptions (from ATS5)

    /// Changeover point exception text
    public internal(set) var changeoverExceptions: [String]
  }

  public enum CodingKeys: String, CodingKey {
    case designation, airwayIdentifier, isRNAV, airwayType
    case routePoints, routeRemarks
    case effectiveDateComponents = "effectiveDate"
  }
}
