import Foundation

/// A miscellaneous activity area such as aerobatic practice areas, glider areas,
/// hang glider areas, space launch areas, ultralight areas, and unmanned aircraft areas.
public struct MiscActivityArea: Record, Identifiable {

  // MARK: - Identification

  /// The unique MAA identifier (e.g., "AA0001")
  public let MAAId: String

  /// The conforming identifier
  public var id: String { MAAId }

  /// The type of activity area
  public let areaType: AreaType?

  /// The name of the activity area
  public let areaName: String?

  // MARK: - Location

  /// The two-letter state abbreviation
  public let stateCode: String?

  /// The state name
  public let stateName: String?

  /// The associated city name
  public let city: String?

  /// The center position.
  public let position: Location?

  // MARK: - Navaid Reference

  /// The identifier of the reference navaid
  public let navaidIdentifier: String?

  /// The navaid facility type code
  public let navaidFacilityTypeCode: String?

  /// The navaid facility type description (e.g., VORTAC, VOR)
  public let navaidFacilityType: String?

  /// The navaid name
  public let navaidName: String?

  /// The azimuth (bearing) from the navaid (degrees).
  public let navaidAzimuth: Double?

  /// The distance from the navaid (nautical miles).
  public let navaidDistance: Double?

  // MARK: - Associated Airport

  /// The identifier of the associated airport
  public let associatedAirportId: String?

  /// The name of the associated airport
  public let associatedAirportName: String?

  /// The site number of the associated airport
  public let associatedAirportSiteNumber: String?

  // MARK: - Nearest Airport (Space Launch only)

  /// The identifier of the nearest airport (space launch areas only)
  public let nearestAirportId: String?

  /// The distance to the nearest airport (nautical miles; space launch areas only).
  public let nearestAirportDistance: Double?

  /// The direction to the nearest airport (space launch areas only)
  public let nearestAirportDirection: Direction?

  // MARK: - Altitude Limits

  /// The maximum altitude allowed.
  public let maximumAltitude: Altitude?

  /// The minimum altitude allowed.
  public let minimumAltitude: Altitude?

  // MARK: - Area Definition

  /// The area radius from the center point (nautical miles).
  public let areaRadius: Double?

  /// Whether to show on VFR chart
  public let isShownOnVFRChart: Bool?

  /// The area description
  public let areaDescription: String?

  /// The area use
  public let areaUse: String?

  // MARK: - Variable Data

  /// The polygon coordinates defining the boundary
  public internal(set) var polygonCoordinates: [PolygonCoordinate]

  /// Times of use descriptions
  public internal(set) var timesOfUse: [String]

  /// User group names
  public internal(set) var userGroups: [String]

  /// Contact facilities
  public internal(set) var contactFacilities: [ContactFacility]

  /// NOTAM check locations (space launch areas only)
  public internal(set) var checkForNOTAMs: [String]

  /// Additional remarks
  public internal(set) var remarks: [String]

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  // MARK: - Types

  /// The type of miscellaneous activity area
  public enum AreaType: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable, Sendable {
    case aerobaticPractice = "AEROBATIC PRACTICE"
    case glider = "GLIDER"
    case hangGlider = "HANG GLIDER"
    case spaceLaunch = "SPACE LAUNCH"
    case ultralight = "ULTRALIGHT"
    case unmannedAircraft = "UNMANNED AIRCRAFT"
    case other = "OTHER"

    public var description: String {
      switch self {
        case .aerobaticPractice: return "Aerobatic Practice"
        case .glider: return "Glider"
        case .hangGlider: return "Hang Glider"
        case .spaceLaunch: return "Space Launch"
        case .ultralight: return "Ultralight"
        case .unmannedAircraft: return "Unmanned Aircraft"
        case .other: return "Other"
      }
    }
  }

  /// A polygon coordinate defining the boundary of the activity area
  public struct PolygonCoordinate: Record, Equatable, Hashable, Codable, Sendable {
    /// The position.
    public let position: Location?
  }

  /// Contact facility information for the activity area
  public struct ContactFacility: Record, Equatable, Hashable, Codable, Sendable {
    /// The facility identifier
    public let facilityId: String?

    /// The facility name (may include type concatenated)
    public let facilityName: String?

    /// The commercial (civil) frequency (kHz).
    public let commercialFrequency: UInt?

    /// Whether to show on VFR chart for commercial frequency
    public let showCommercialOnChart: Bool

    /// The military frequency (kHz).
    public let militaryFrequency: UInt?

    /// Whether to show on VFR chart for military frequency
    public let showMilitaryOnChart: Bool
  }

  public enum CodingKeys: String, CodingKey {
    case MAAId, areaType, areaName, stateCode, stateName, city, position
    case navaidIdentifier, navaidFacilityTypeCode, navaidFacilityType, navaidName
    case navaidAzimuth, navaidDistance
    case associatedAirportId, associatedAirportName, associatedAirportSiteNumber
    case nearestAirportId, nearestAirportDistance, nearestAirportDirection
    case maximumAltitude, minimumAltitude, areaRadius, isShownOnVFRChart
    case areaDescription, areaUse
    case polygonCoordinates, timesOfUse, userGroups, contactFacilities
    case checkForNOTAMs, remarks
  }
}
