import Foundation

/// A location identifier record from the LID file.
///
/// Location identifiers are assigned to various aviation facilities including airports,
/// navaids, ILS systems, flight service stations, ARTCCs, and other facilities.
/// A single location identifier may be shared by multiple facility types.
public struct LocationIdentifier: Record, Identifiable {

  // MARK: - Identification

  /// The location identifier (e.g., "LAX", "JFK", "ORD").
  public let identifier: String

  /// Unique identifier for the record.
  public var id: String { identifier }

  /// The group code (USA, DOD, or CAN).
  public let groupCode: GroupCode?

  // MARK: - Basic Location Information

  /// The FAA region code (e.g., "AWP", "AEA", "ASW").
  public let FAARegion: String?

  /// The state postal code.
  public let stateCode: String?

  /// The city name associated with this identifier.
  public let city: String?

  /// The controlling ARTCC identifier (e.g., "ZLA", "ZNY").
  public let controllingARTCC: String?

  /// The controlling ARTCC computer identifier (e.g., "ZCL", "ZCN").
  public let controllingARTCCComputerId: String?

  // MARK: - Landing Facility Information

  /// The landing facility name (if this identifier is assigned to an airport).
  public let landingFacilityName: String?

  /// The landing facility type.
  public let landingFacilityType: LandingFacilityType?

  /// The tie-in FSS identifier for the landing facility.
  public let landingFacilityFSS: String?

  // MARK: - Navaid Information

  /// Navaids associated with this location identifier (up to 4).
  public let navaids: [NavaidInfo]

  /// The tie-in FSS identifier for navaids.
  public let navaidFSS: String?

  // MARK: - ILS Information

  /// The ILS runway end (e.g., "08", "18R", "36L").
  public let ILSRunwayEnd: String?

  /// The ILS facility type.
  public let ilsFacilityType: ILSFacilityType?

  /// The location identifier of the ILS airport.
  public let ILSAirportIdentifier: String?

  /// The ILS airport name.
  public let ILSAirportName: String?

  /// The tie-in FSS identifier for the ILS.
  public let ILSFSS: String?

  // MARK: - FSS Information

  /// The FSS name (if this identifier is assigned to an FSS).
  public let FSSName: String?

  // MARK: - ARTCC Information

  /// The ARTCC name (if this identifier is assigned to an ARTCC).
  public let ARTCCName: String?

  /// The ARTCC facility type.
  public let artccFacilityType: ARTCCFacilityType?

  // MARK: - Other Facility Information

  /// Whether this is a flight watch station.
  public let isFlightWatchStation: Bool?

  /// The other facility name/description.
  public let otherFacilityName: String?

  /// The other facility type.
  public let otherFacilityType: OtherFacilityType?

  // MARK: - Effective Date

  /// The effective date of this information.
  public let effectiveDate: DateComponents?

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  // MARK: - Types

  /// The group code for location identifiers.
  public enum GroupCode: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable, Sendable {
    /// United States locations
    case usa = "USA"

    /// Department of Defense overseas locations
    case dod = "DOD"

    /// Canadian locations
    case can = "CAN"

    public var description: String {
      switch self {
        case .usa: return "United States"
        case .dod: return "DOD Overseas"
        case .can: return "Canada"
      }
    }
  }

  /// Landing facility types.
  public enum LandingFacilityType: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable,
    Sendable
  {
    case airport = "AIRPORT"
    case balloonport = "BALLOONPORT"
    case gliderport = "GLIDERPORT"
    case heliport = "HELIPORT"
    case seaplaneBase = "SEAPLANE BASE"
    case stolport = "STOLPORT"
    case ultralight = "ULTRALIGHT"

    public var description: String { rawValue }
  }

  /// Other facility types.
  public enum OtherFacilityType: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable,
    Sendable
  {
    case administrative = "ADMINISTRATIVE"
    case georef = "GEOREF"
    case specialUse = "SPECIAL USE"
    case weatherStation = "WEATHER STATION"

    public var description: String { rawValue }
  }

  /// ARTCC facility types.
  public enum ARTCCFacilityType: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable,
    Sendable
  {
    /// Air Route Traffic Control Center
    case ARTCC = "ARTCC"

    /// ARTCC Computer
    case ARTCCComputer = "ARTCC COMPUTER"

    /// Combined Center/Radar Approach Control
    case CERAP = "CERAP"

    public var description: String { rawValue }
  }

  /// ILS facility types.
  public enum ILSFacilityType: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable,
    Sendable
  {
    /// Instrument Landing System
    case ILS = "ILS"

    /// ILS with Distance Measuring Equipment
    case ILS_DME = "ILS/DME"

    /// Localizer-only approach
    case localizer = "LOCALIZER"

    /// Localizer with Distance Measuring Equipment
    case LOC_DME = "LOC/DME"

    /// Localizer with Glideslope
    case LOC_GS = "LOC/GS"

    /// Localizer-type Directional Aid
    case LDA = "LDA"

    /// LDA with Distance Measuring Equipment
    case LDA_DME = "LDA/DME"

    /// Simplified Directional Facility
    case SDF = "SDF"

    /// SDF with Distance Measuring Equipment
    case SDF_DME = "SF/DME"

    public var description: String { rawValue }
  }

  /// Navaid facility types for location identifiers.
  public enum NavaidFacilityType: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable,
    Sendable
  {
    /// Distance Measuring Equipment
    case DME = "DME"

    /// Fan Marker
    case fanMarker = "FAN MARKER"

    /// Non-Directional Beacon
    case NDB = "NDB"

    /// NDB with Distance Measuring Equipment
    case NDB_DME = "NDB/DME"

    /// Tactical Air Navigation
    case TACAN = "TACAN"

    /// VHF Omnidirectional Range
    case VOR = "VOR"

    /// VOR with Distance Measuring Equipment
    case VOR_DME = "VOR/DME"

    /// VOR and TACAN combined
    case VORTAC = "VORTAC"

    /// VOR Test Facility
    case VOT = "VOT"

    public var description: String { rawValue }
  }

  /// A navaid associated with this location identifier.
  public struct NavaidInfo: Record, Equatable, Hashable, Codable, Sendable {
    /// The navaid facility name.
    public let name: String

    /// The navaid facility type.
    public let facilityType: NavaidFacilityType?
  }

  public enum CodingKeys: String, CodingKey {
    case identifier, groupCode, FAARegion, stateCode, city
    case controllingARTCC, controllingARTCCComputerId
    case landingFacilityName, landingFacilityType, landingFacilityFSS
    case navaids, navaidFSS
    case ILSRunwayEnd, ilsFacilityType, ILSAirportIdentifier, ILSAirportName, ILSFSS
    case FSSName, ARTCCName, artccFacilityType
    case isFlightWatchStation, otherFacilityName, otherFacilityType
    case effectiveDate
  }
}
