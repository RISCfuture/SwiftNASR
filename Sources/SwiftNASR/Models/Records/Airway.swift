import Foundation

/// An airway segment in the National Airspace System.
///
/// Airways are established routes between navaids or fixes that provide
/// a structured path for instrument flight operations. They include
/// VOR airways (V-routes), Jet routes (J-routes), and RNAV routes (Q and T routes).
public struct Airway: ParentRecord {

  // MARK: - Type Aliases

  /// Shared point type enum (same as ATSAirway.PointType).
  public typealias PointType = ATSAirway.PointType

  // MARK: - Properties

  /// The airway designation (e.g., "V16", "J80", "Q102").
  public let designation: String

  /// The type of airway (Federal, Alaska, Hawaii).
  public let type: AirwayType

  /// The segments that make up this airway.
  public internal(set) var segments = [Segment]()

  /// General remarks about the entire airway.
  public internal(set) var remarks = [String]()

  weak var data: NASRData?

  public var id: String { "\(designation)\(type.rawValue)" }

  // MARK: - Nested Types

  /// Types of airways.
  public enum AirwayType: String, RecordEnum {
    /// Standard US Federal airway.
    case federal = " "

    /// Alaska airway.
    case alaska = "A"

    /// Hawaii airway.
    case hawaii = "H"

    public static var synonyms: [String: Self] { ["": .federal] }
  }

  /// A point along the airway.
  public struct Point: Record {

    // MARK: - Properties

    /// The sequence number of this point along the airway.
    public let sequenceNumber: UInt

    /// The name of the navaid or fix at this point.
    public let name: String?

    /// The type of point (navaid or fix type).
    public let pointType: PointType?

    /// The position of the point.
    public let position: Location?

    /// The state code where the point is located.
    public let stateCode: String?

    /// The ICAO region code for fixes.
    public let ICAORegionCode: String?

    /// The navaid identifier for navaid points.
    public let navaidId: String?

    /// The minimum reception altitude for fix points (feet).
    public let minimumReceptionAltitudeFt: UInt?

    /// Remarks specific to this point.
    public internal(set) var remarks = [String]()

    // MARK: - Nested Types

    public enum CodingKeys: String, CodingKey {
      case sequenceNumber, name, pointType, position, stateCode
      case ICAORegionCode, navaidId, minimumReceptionAltitudeFt, remarks
    }
  }

  /// A segment between two points on the airway.
  public struct Segment: Record {

    // MARK: - Properties

    /// The sequence number of the starting point.
    public let sequenceNumber: UInt

    /// The starting point of this segment.
    public let point: Point

    /// The changeover point information (for VOR/Jet routes).
    public let changeoverPoint: ChangeoverPoint?

    /// The altitude information for this segment.
    public let altitudes: SegmentAltitudes

    /// The distance to the next point (nautical miles).
    public let distanceToNextNM: Float?

    /// The magnetic course of the segment (degrees).
    public let magneticCourseDeg: Float?

    /// The magnetic course in the opposite direction (degrees).
    public let magneticCourseOppositeDeg: Float?

    /// The track angle outbound (for RNAV routes).
    public let trackAngleOutbound: TrackAnglePair?

    /// The track angle inbound (for RNAV routes).
    public let trackAngleInbound: TrackAnglePair?

    /// Whether there's a gap in signal coverage.
    public let hasSignalCoverageGap: Bool?

    /// Whether this is US airspace only.
    public let isUSAirspaceOnly: Bool?

    /// Whether this is a gap in the airway.
    public let isAirwayGap: Bool?

    /// Whether this is a dogleg point.
    public let isDogleg: Bool?

    /// The ARTCC with jurisdiction over this segment.
    public let ARTCCID: String?

    /// Changeover exception text.
    public internal(set) var changeoverExceptions = [String]()

    // MARK: - Nested Types

    public enum CodingKeys: String, CodingKey {
      case sequenceNumber, point, changeoverPoint, altitudes, distanceToNextNM
      case magneticCourseDeg, magneticCourseOppositeDeg, trackAngleOutbound, trackAngleInbound
      case hasSignalCoverageGap, isUSAirspaceOnly, isAirwayGap, isDogleg
      case ARTCCID, changeoverExceptions
    }
  }

  /// Changeover point information for VOR/Jet routes.
  public struct ChangeoverPoint: Record {

    // MARK: - Properties

    /// Distance to the changeover point (nautical miles).
    public let distanceNM: UInt?

    /// The navaid name at the changeover point.
    public let navaidName: String?

    /// The navaid type at the changeover point.
    public let navaidType: String?

    /// The position of the changeover navaid.
    public let position: Location?

    /// The state code of the changeover navaid.
    public let stateCode: String?

    // MARK: - Nested Types

    public enum CodingKeys: String, CodingKey {
      case distanceNM, navaidName, navaidType, position, stateCode
    }
  }

  /// Altitude information for an airway segment.
  public struct SegmentAltitudes: Record {

    // MARK: - Properties

    /// Minimum Enroute Altitude (feet).
    public let MEAFt: UInt?

    /// MEA direction.
    public let MEADirection: BoundDirection?

    /// MEA in opposite direction (feet).
    public let MEAOppositeFt: UInt?

    /// MEA opposite direction.
    public let MEAOppositeDirection: BoundDirection?

    /// Maximum Authorized Altitude (feet).
    public let MAAFt: UInt?

    /// Minimum Obstruction Clearance Altitude (feet).
    public let MOCAFt: UInt?

    /// Minimum Crossing Altitude (feet).
    public let MCAFt: UInt?

    /// MCA direction.
    public let MCADirection: BoundDirection?

    /// MCA in opposite direction (feet).
    public let MCAOppositeFt: UInt?

    /// MCA opposite direction.
    public let MCAOppositeDirection: BoundDirection?

    /// GNSS MEA (feet).
    public let GNSS_MEAFt: UInt?

    /// GNSS MEA direction.
    public let GNSS_MEADirection: BoundDirection?

    /// GNSS MEA opposite (feet).
    public let GNSS_MEAOppositeFt: UInt?

    /// GNSS MEA opposite direction.
    public let GNSS_MEAOppositeDirection: BoundDirection?

    /// DME/DME/IRU MEA (feet).
    public let DME_MEAFt: UInt?

    /// DME/DME/IRU MEA direction.
    public let DME_MEADirection: BoundDirection?

    /// DME/DME/IRU MEA opposite (feet).
    public let DME_MEAOppositeFt: UInt?

    /// DME/DME/IRU MEA opposite direction.
    public let DME_MEAOppositeDirection: BoundDirection?

    // MARK: - Nested Types

    public enum CodingKeys: String, CodingKey {
      case MEAFt, MEADirection, MEAOppositeFt, MEAOppositeDirection
      case MAAFt, MOCAFt, MCAFt, MCADirection, MCAOppositeFt, MCAOppositeDirection
      case GNSS_MEAFt, GNSS_MEADirection, GNSS_MEAOppositeFt, GNSS_MEAOppositeDirection
      case DME_MEAFt, DME_MEADirection, DME_MEAOppositeFt, DME_MEAOppositeDirection
    }
  }

  public enum CodingKeys: String, CodingKey {
    case designation, type, segments, remarks
  }
}
