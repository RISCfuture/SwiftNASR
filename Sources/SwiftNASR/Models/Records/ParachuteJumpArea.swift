import Foundation

/// A parachute jump area (PJA).
///
/// Parachute jump areas are designated airspace where parachute jumping
/// activities take place. They are described relative to a navaid facility
/// and include information about the drop zone, times of use, and contact
/// facilities.
public struct ParachuteJumpArea: Record, Identifiable {

  // MARK: - Properties

  /// Unique PJA identifier.
  public let PJAId: String

  /// Associated navaid identifier.
  public let navaidIdentifier: String?

  /// Navaid facility type code (e.g., "D" for VOR/DME).
  public let navaidFacilityTypeCode: String?

  /// Navaid facility type description (e.g., "VOR/DME", "VORTAC").
  public let navaidFacilityType: String?

  /// Azimuth from navaid (degrees, 000.0-359.99).
  public let azimuthFromNavaid: Double?

  /// Distance from navaid (nautical miles).
  public let distanceFromNavaid: Double?

  /// Navaid name.
  public let navaidName: String?

  /// State abbreviation (two-letter postal code).
  public let stateCode: String?

  /// State name.
  public let stateName: String?

  /// Associated city name.
  public let city: String?

  /// Position of the PJA center point.
  public let position: Location?

  /// Associated airport name.
  public let airportName: String?

  /// Associated airport site number.
  public let airportSiteNumber: String?

  /// Drop zone name.
  public let dropZoneName: String?

  /// Maximum altitude allowed.
  public let maxAltitude: Altitude?

  /// Area radius from center point (nautical miles).
  public let radius: Double?

  /// Whether sectional charting is required.
  public let sectionalChartingRequired: Bool?

  /// Whether the area is published in Airport/Facility Directory.
  public let publishedInAFD: Bool?

  /// Additional descriptive text for the area.
  public let additionalDescription: String?

  /// Associated FSS identifier.
  public let FSSIdentifier: String?

  /// Associated FSS name.
  public let FSSName: String?

  /// PJA use type.
  public let useType: UseType?

  /// Times of use descriptions.
  public internal(set) var timesOfUse: [String]

  /// User groups.
  public internal(set) var userGroups: [UserGroup]

  /// Contact facilities.
  public internal(set) var contactFacilities: [ContactFacility]

  /// Remarks.
  public internal(set) var remarks: [String]

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  public var id: String {
    PJAId
  }

  // MARK: - Nested Types

  /// The type of use for a parachute jump area.
  public enum UseType: String, Codable, Sendable {
    /// Civil use.
    case civil = "CIVIL"

    /// Military use.
    case military = "MILITARY"

    /// Joint civil and military use.
    case joint = "JOINT"
  }

  /// A user group associated with a parachute jump area.
  public struct UserGroup: Record {
    /// User group name.
    public let name: String

    /// User group description.
    public let description: String?

    public enum CodingKeys: String, CodingKey {
      case name, description
    }
  }

  /// A contact facility for a parachute jump area.
  public struct ContactFacility: Record {
    /// Contact facility identifier.
    public let facilityId: String?

    /// Contact facility name (type concatenated to name).
    public let facilityName: String?

    /// Related location identifier.
    public let relatedLocationId: String?

    /// Commercial frequency (kHz).
    public let commercialFrequency: UInt?

    /// Whether commercial frequency is charted.
    public let commercialCharted: Bool?

    /// Military frequency (kHz).
    public let militaryFrequency: UInt?

    /// Whether military frequency is charted.
    public let militaryCharted: Bool?

    /// Sector.
    public let sector: String?

    /// Altitude.
    public let altitude: String?

    public enum CodingKeys: String, CodingKey {
      case facilityId, facilityName, relatedLocationId
      case commercialFrequency, commercialCharted
      case militaryFrequency, militaryCharted
      case sector, altitude
    }
  }

  public enum CodingKeys: String, CodingKey {
    case PJAId, navaidIdentifier, navaidFacilityTypeCode, navaidFacilityType
    case azimuthFromNavaid, distanceFromNavaid, navaidName
    case stateCode, stateName, city
    case position
    case airportName, airportSiteNumber, dropZoneName
    case maxAltitude, radius
    case sectionalChartingRequired, publishedInAFD
    case additionalDescription, FSSIdentifier, FSSName, useType
    case timesOfUse, userGroups, contactFacilities, remarks
  }
}
