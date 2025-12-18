import Foundation

/// A military training route (MTR).
///
/// Military training routes are routes used by military aircraft for low-altitude
/// navigation training. They are categorized as either IFR (IR) or VFR (VR) routes.
public struct MilitaryTrainingRoute: Record, Identifiable {

  // MARK: - Properties

  /// Route type (IR or VR).
  public let routeType: RouteType

  /// Route identifier number.
  public let routeIdentifier: String

  /// Publication effective date.
  public let effectiveDate: DateComponents?

  /// FAA region code.
  public let FAARegionCode: String?

  /// ARTCC identifiers (up to 20).
  public internal(set) var ARTCCIdentifiers: [String]

  /// Flight service station identifiers within 150 NM of the route (up to 40).
  public internal(set) var FSSIdentifiers: [String]

  /// Times of use text.
  public let timesOfUse: String?

  /// Standard operating procedures text lines.
  public internal(set) var operatingProcedures: [String]

  /// Route width description text lines.
  public internal(set) var routeWidthDescriptions: [String]

  /// Terrain following operations text lines.
  public internal(set) var terrainFollowingOperations: [String]

  /// Route points along the route.
  public internal(set) var routePoints: [RoutePoint]

  /// Scheduling and originating agencies.
  public internal(set) var agencies: [Agency]

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  public var id: String {
    "\(routeType.rawValue)\(routeIdentifier)"
  }

  // MARK: - Types

  /// The type of military training route.
  public enum RouteType: String, RecordEnum {
    /// IFR military training route.
    case IFR = "IR"

    /// VFR military training route.
    case VFR = "VR"
  }

  /// The type of scheduling agency.
  public enum AgencyType: String, RecordEnum {
    /// Originating agency.
    case originating = "O"

    /// First scheduling agency.
    case scheduling1 = "S1"

    /// Second scheduling agency.
    case scheduling2 = "S2"

    /// Third scheduling agency.
    case scheduling3 = "S3"

    /// Fourth scheduling agency.
    case scheduling4 = "S4"
  }

  // MARK: - Nested Types

  /// A point along a military training route.
  public struct RoutePoint: Record {
    /// Point identifier (A, B, C, etc.).
    public let pointId: String

    /// Segment description text leading up to the point.
    public let segmentDescriptionLeading: String?

    /// Segment description text leaving the point.
    public let segmentDescriptionLeaving: String?

    /// Related navaid identifier.
    public let navaidIdentifier: String?

    /// Bearing from point to navaid, in degrees.
    public let navaidBearingDeg: UInt?

    /// Distance from point to navaid, in nautical miles.
    public let navaidDistanceNM: UInt?

    /// Position of the point.
    public let position: Location?

    /// Sort sequence number (segment sequence along route).
    public let sequenceNumber: UInt?

    public enum CodingKeys: String, CodingKey {
      case pointId
      case segmentDescriptionLeading, segmentDescriptionLeaving
      case navaidIdentifier, navaidBearingDeg, navaidDistanceNM
      case position, sequenceNumber
    }
  }

  /// A scheduling or originating agency for a military training route.
  public struct Agency: Record {
    /// Agency type (originating or scheduling).
    public let agencyType: AgencyType?

    /// Agency organization name.
    public let organizationName: String?

    /// Agency station.
    public let station: String?

    /// Agency address.
    public let address: String?

    /// Agency city.
    public let city: String?

    /// Agency state (two-letter postal code).
    public let stateCode: String?

    /// Agency ZIP code.
    public let zipCode: String?

    /// Commercial phone number.
    public let commercialPhone: String?

    /// DSN (military) phone number.
    public let DSNPhone: String?

    /// Agency hours of operation.
    public let hours: String?

    public enum CodingKeys: String, CodingKey {
      case agencyType, organizationName, station, address, city
      case stateCode, zipCode, commercialPhone, DSNPhone, hours
    }
  }

  public enum CodingKeys: String, CodingKey {
    case routeType, routeIdentifier, effectiveDate, FAARegionCode
    case ARTCCIdentifiers, FSSIdentifiers, timesOfUse
    case operatingProcedures, routeWidthDescriptions, terrainFollowingOperations
    case routePoints, agencies
  }
}
