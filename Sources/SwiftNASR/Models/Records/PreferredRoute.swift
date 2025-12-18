import Foundation

/// A Preferred IFR Route between two locations.
///
/// Preferred routes are established between busier airports to increase system
/// efficiency and capacity. They normally extend through one or more ARTCC areas
/// and are designed to achieve balanced traffic flows among high density terminals.
public struct PreferredRoute: Record, Identifiable {

  // MARK: - Properties

  /// Origin facility location identifier.
  public let originIdentifier: String

  /// Destination facility location identifier.
  public let destinationIdentifier: String

  /// Type of preferred route.
  public let routeType: RouteType?

  /// Route identifier sequence number (1-99).
  public let sequenceNumber: UInt

  /// Type of preferred route (description).
  public let routeTypeDescription: String?

  /// Preferred route area description.
  public let areaDescription: String?

  /// Preferred route altitude description.
  public let altitudeDescription: String?

  /// Aircraft allowed/limitations description.
  public let aircraftDescription: String?

  /// Effective hours (GMT) description.
  public internal(set) var effectiveHours: [String]

  /// Route direction limitations description.
  public let directionLimitations: String?

  /// NAR type (Common, Non-Common).
  public let NARType: String?

  /// Designator.
  public let designator: String?

  /// Destination city.
  public let destinationCity: String?

  /// Route segments.
  public internal(set) var segments = [Segment]()

  public var id: String {
    "\(originIdentifier)-\(destinationIdentifier)-\(routeType?.rawValue ?? "")-\(sequenceNumber)"
  }

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  // MARK: - Types

  /// Type of preferred route.
  public enum RouteType: String, RecordEnum {
    /// Low altitude route
    case low = "L"

    /// High altitude route
    case high = "H"

    /// Low altitude single direction
    case lowSingleDirection = "LSD"

    /// High altitude single direction
    case highSingleDirection = "HSD"

    /// Special low altitude directional
    case specialLowDirectional = "SLD"

    /// Special high altitude directional
    case specialHighDirectional = "SHD"

    /// Tower Enroute Control
    case towerEnrouteControl = "TEC"

    /// North American Route
    case northAmericanRoute = "NAR"
  }

  /// Type of segment in a preferred route.
  public enum SegmentType: String, RecordEnum {
    case airway = "AIRWAY"
    case fix = "FIX"
    case departureProc = "DP"
    case arrivalProc = "STAR"
    case navaid = "NAVAID"
    case unknown = "UNKNOWN"
  }

  /// Radial and optional distance from a navaid.
  public enum RadialDistance: Hashable, Sendable, Codable {
    /// Radial only (bearing in degrees).
    case radialDeg(UInt16)

    /// Radial (degrees) and distance (nautical miles) from navaid.
    case radialDistanceDegNM(radialDeg: UInt16, distanceNM: UInt16)
  }

  // MARK: - Nested Types

  /// A segment of a preferred route.
  public struct Segment: Record {
    /// Segment sequence number within the route.
    public let sequenceNumber: UInt

    /// Segment identifier (navaid ident, airway number, fix name, etc.).
    public let identifier: String?

    /// Segment type.
    public let segmentType: SegmentType?

    /// Fix state code (postal code). Only for fix segments.
    public let fixStateCode: String?

    /// ICAO region code.
    public let ICAORegionCode: String?

    /// Navaid facility type code. Only for navaid segments.
    public let navaidType: Navaid.FacilityType?

    /// Navaid facility type description. Only for navaid segments.
    public let navaidTypeDescription: String?

    /// Radial and distance from navaid. Only for navaid segments.
    public let radialDistance: RadialDistance?

    public enum CodingKeys: String, CodingKey {
      case sequenceNumber, identifier, segmentType, fixStateCode
      case ICAORegionCode, navaidType, navaidTypeDescription, radialDistance
    }
  }

  public enum CodingKeys: String, CodingKey {
    case originIdentifier, destinationIdentifier, routeType, sequenceNumber
    case routeTypeDescription, areaDescription, altitudeDescription
    case aircraftDescription, effectiveHours, directionLimitations
    case NARType, designator, destinationCity, segments
  }
}
