import Foundation

/// An Instrument Landing System (ILS) facility providing precision approach guidance.
///
/// ILS facilities consist of several components: a localizer for lateral guidance,
/// an optional glide slope for vertical guidance, optional distance measuring equipment (DME),
/// and optional marker beacons (outer, middle, inner) for position fixes along the approach.
public struct ILS: ParentRecord {

  // MARK: - Identification

  /// Airport site number identifier (e.g., "04508.*A").
  public let airportSiteNumber: String

  /// Runway end identifier (e.g., "18", "36L").
  public let runwayEndId: String

  /// Type of ILS system.
  public let systemType: SystemType

  /// Identification code of the ILS (e.g., "I-ORD"). The identifier is prefixed with "I-".
  public let ILSId: String

  /// Airport identifier (e.g., "ORD" for Chicago O'Hare).
  public let airportId: String

  // MARK: - Location Information

  /// Airport name (e.g., "CHICAGO O'HARE INTL").
  public let airportName: String

  /// Associated city name (e.g., "CHICAGO").
  public let city: String

  /// Two-letter state/territory postal code.
  public let stateCode: String?

  /// Full state name (e.g., "ILLINOIS").
  public let stateName: String?

  /// FAA region code (e.g., "ACE" for Central).
  public let regionCode: String?

  // MARK: - Runway Information

  /// Runway length (feet).
  public let runwayLength: UInt?

  /// Runway width (feet).
  public let runwayWidth: UInt?

  // MARK: - System Information

  /// Category of the ILS (I, II, IIIA, IIIB, IIIC).
  public let category: Category?

  /// Name of the facility owner.
  public let owner: String?

  /// Name of the facility operator.
  public let `operator`: String?

  /// Approach bearing.
  public let approachBearing: Bearing<Float>?

  /// The variation between magnetic and true north (degrees; positive is east).
  public let magneticVariation: Int?

  /// Information effective date.
  public let effectiveDate: DateComponents?

  // MARK: - Components

  /// The localizer component (always present for ILS).
  public internal(set) var localizer: Localizer?

  /// The glide slope component (optional).
  public internal(set) var glideSlope: GlideSlope?

  /// The distance measuring equipment component (optional).
  public internal(set) var dme: DME?

  /// Marker beacons (up to 3: outer, middle, inner).
  public internal(set) var markers = [MarkerBeacon]()

  /// Remarks about the ILS.
  public internal(set) var remarks = [String]()

  weak var data: NASRData?

  public var id: String { "\(airportSiteNumber)_\(runwayEndId)_\(systemType.rawValue)" }

  // MARK: - Enums

  /// Types of ILS systems.
  public enum SystemType: String, RecordEnum {
    /// Standard Instrument Landing System.
    case ILS = "ILS"

    /// Simplified Directional Facility.
    case SDF = "SDF"

    /// Localizer only.
    case localizer = "LOCALIZER"

    /// Localizer-Type Directional Aid.
    case LDA = "LDA"

    /// ILS with Distance Measuring Equipment.
    case ILSDME = "ILS/DME"

    /// SDF with Distance Measuring Equipment.
    case SDFDME = "SDF/DME"

    /// Localizer with Distance Measuring Equipment.
    case LOCDME = "LOC/DME"

    /// Localizer with Glide Slope.
    case LOCGS = "LOC/GS"

    /// LDA with Distance Measuring Equipment.
    case LDADME = "LDA/DME"

    /// Local Area Augmentation System (GBAS).
    case LAAS = "LAAS"

    public static var synonyms: [String: Self] {
      [
        "LS": .ILS,
        "LD": .LDA,
        "LG": .LOCGS,
        "LE": .ILSDME,
        "SD": .SDF,
        "LC": .localizer
      ]
    }
  }

  /// ILS approach categories.
  public enum Category: String, RecordEnum {
    /// Category I - Decision height not lower than 200 feet.
    case I

    /// Category II - Decision height lower than 200 feet but not lower than 100 feet.
    case II

    /// Category IIIA - Decision height lower than 100 feet or no decision height.
    case IIIA

    /// Category IIIB - No decision height and RVR not less than 150 feet.
    case IIIB

    /// Category IIIC - No decision height and no RVR limitations.
    case IIIC

    /// Category III (unspecified sub-category).
    case III

    public static var synonyms: [String: Self] {
      ["1": .I, "2": .II, "3": .III, "3A": .IIIA, "3B": .IIIB, "3C": .IIIC]
    }
  }

  /// Source of latitude/longitude or distance information.
  public enum PositionSource: String, RecordEnum {
    /// Air Force.
    case airForce = "A"

    /// Coast Guard.
    case coastGuard = "C"

    /// Canadian AIRAC.
    case canadianAIRAC = "D"

    /// FAA.
    case FAA = "F"

    /// Tech Ops (AFS-530).
    case techOps = "FS"

    /// NOS (Historical).
    case NOS = "G"

    /// NGS.
    case NGS = "K"

    /// DOD (NGA).
    case DOD = "M"

    /// US Navy.
    case navy = "N"

    /// Owner.
    case owner = "O"

    /// NOS Photo Survey (Historical).
    case NOSPhotoSurvey = "P"

    /// Quad Plot (Historical).
    case quadPlot = "Q"

    /// Army.
    case army = "R"

    /// SIAP.
    case SIAP = "S"

    /// 3rd Party Survey.
    case thirdPartySurvey = "T"

    /// Surveyed.
    case surveyed = "Z"
  }

  /// Back course status.
  public enum BackCourseStatus: String, RecordEnum {
    /// Back course is restricted.
    case restricted = "RESTRICTED"

    /// No restrictions on back course.
    case noRestrictions = "NO RESTRICTIONS"

    /// Back course is usable.
    case usable = "USABLE"

    /// Back course is unusable.
    case unusable = "UNUSABLE"

    public static var synonyms: [String: Self] {
      ["Y": .usable, "N": .unusable, "U": .unusable]
    }
  }

  /// Localizer service codes.
  public enum LocalizerServiceCode: String, RecordEnum {
    /// Approach Control.
    case approachControl = "AP"

    /// Automated Terminal Information Services.
    case ATIS = "AT"

    /// No Voice.
    case noVoice = "NV"
  }

  // MARK: - Component Structures

  /// Localizer component providing lateral guidance.
  public struct Localizer: Record {
    /// Operational status.
    public let status: OperationalStatus?

    /// Effective date of operational status.
    public let statusDate: DateComponents?

    /// Position of localizer antenna.
    public let position: Location?

    /// Source of position information.
    public let positionSource: PositionSource?

    /// Distance from approach end of runway (feet; negative = inboard).
    public let distanceFromApproachEnd: Int?

    /// Distance from runway centerline (feet; negative = left, positive = right).
    public let distanceFromCenterline: Int?

    /// Source of distance information.
    public let distanceSource: PositionSource?

    /// Localizer frequency (kHz).
    public let frequency: UInt?

    /// Back course status.
    public let backCourseStatus: BackCourseStatus?

    /// Course width (degrees).
    public let courseWidth: Float?

    /// Course width at threshold (degrees).
    public let courseWidthAtThreshold: Float?

    /// Distance from stop end of runway (feet; negative = inboard).
    public let distanceFromStopEnd: Int?

    /// Direction from stop end of runway.
    public let directionFromStopEnd: LateralDirection?

    /// Service code.
    public let serviceCode: LocalizerServiceCode?

    public enum CodingKeys: String, CodingKey {
      case status, statusDate, position, positionSource
      case distanceFromApproachEnd, distanceFromCenterline
      case distanceSource, frequency, backCourseStatus
      case courseWidth, courseWidthAtThreshold, distanceFromStopEnd
      case directionFromStopEnd, serviceCode
    }
  }

  /// Glide slope component providing vertical guidance.
  public struct GlideSlope: Record {
    /// Operational status.
    public let status: OperationalStatus?

    /// Effective date of operational status.
    public let statusDate: DateComponents?

    /// Position of glide slope antenna.
    public let position: Location?

    /// Source of position information.
    public let positionSource: PositionSource?

    /// Distance from approach end of runway (feet; negative = inboard).
    public let distanceFromApproachEnd: Int?

    /// Distance from runway centerline (feet; negative = left, positive = right).
    public let distanceFromCenterline: Int?

    /// Source of distance information.
    public let distanceSource: PositionSource?

    /// Glide slope class/type.
    public let glideSlopeType: GlidePathType?

    /// Glide slope angle (degrees).
    public let angle: Float?

    /// Glide slope transmission frequency (kHz).
    public let frequency: UInt?

    /// Elevation of runway adjacent to glide slope antenna (feet MSL).
    public let adjacentRunwayElevation: Float?

    /// Glide slope class/type.
    public enum GlidePathType: String, RecordEnum {
      /// Standard glide slope.
      case glideSlope = "GLIDE SLOPE"

      /// Glide slope with DME.
      case glideSlopeDME = "GLIDE SLOPE/DME"

      public static var synonyms: [String: Self] {
        ["GS": .glideSlope, "GD": .glideSlopeDME]
      }
    }

    public enum CodingKeys: String, CodingKey {
      case status, statusDate, position, positionSource
      case distanceFromApproachEnd, distanceFromCenterline
      case distanceSource, glideSlopeType, angle, frequency
      case adjacentRunwayElevation
    }
  }

  /// Distance Measuring Equipment component.
  public struct DME: Record {
    /// Operational status.
    public let status: OperationalStatus?

    /// Effective date of operational status.
    public let statusDate: DateComponents?

    /// Position of DME antenna.
    public let position: Location?

    /// Source of position information.
    public let positionSource: PositionSource?

    /// Distance from approach end of runway (feet; negative = inboard).
    public let distanceFromApproachEnd: Int?

    /// Distance from runway centerline (feet; negative = left, positive = right).
    public let distanceFromCenterline: Int?

    /// Source of distance information.
    public let distanceSource: PositionSource?

    /// Channel on which distance data is transmitted (e.g., "032X").
    public let channel: String?

    /// Distance from stop end of runway (feet; negative = inboard).
    public let distanceFromStopEnd: Int?

    public enum CodingKeys: String, CodingKey {
      case status, statusDate, position, positionSource
      case distanceFromApproachEnd, distanceFromCenterline
      case distanceSource, channel, distanceFromStopEnd
    }
  }

  /// Marker beacon component.
  public struct MarkerBeacon: Record {
    /// Type of marker beacon.
    public let markerType: MarkerType

    /// Operational status.
    public let status: OperationalStatus?

    /// Effective date of operational status.
    public let statusDate: DateComponents?

    /// Position of marker beacon.
    public let position: Location?

    /// Source of position information.
    public let positionSource: PositionSource?

    /// Distance from approach end of runway (feet; negative = inboard).
    public let distanceFromApproachEnd: Int?

    /// Distance from runway centerline (feet; negative = left, positive = right).
    public let distanceFromCenterline: Int?

    /// Source of distance information.
    public let distanceSource: PositionSource?

    /// Facility type at marker.
    public let facilityType: MarkerFacilityType?

    /// Location identifier of beacon at marker.
    public let locationId: String?

    /// Name of the marker locator beacon.
    public let name: String?

    /// Frequency of locator beacon (kHz).
    public let frequency: UInt?

    /// Collocated navaid identifier and type (e.g., "AN*NDB").
    public let collocatedNavaid: String?

    /// Low powered NDB status.
    public let lowPoweredNDBStatus: OperationalStatus?

    /// Service provided by marker.
    public let service: String?

    /// Type of marker beacon.
    public enum MarkerType: String, RecordEnum {
      /// Inner marker.
      case inner = "IM"

      /// Middle marker.
      case middle = "MM"

      /// Outer marker.
      case outer = "OM"

      /// Back course marker.
      case backCourse = "BC"
    }

    /// Facility type at marker location.
    public enum MarkerFacilityType: String, RecordEnum {
      /// Marker beacon only.
      case marker = "MARKER"

      /// Compass locator.
      case compassLocator = "COMLO"

      /// Non-directional beacon.
      case NDB = "NDB"

      /// Marker with compass locator.
      case markerCompassLocator = "MARKER/COMLO"

      /// Marker with NDB.
      case markerNDB = "MARKER/NDB"

      public static var synonyms: [String: Self] {
        ["MK": .marker, "CL": .compassLocator, "MC": .markerCompassLocator, "MN": .markerNDB]
      }
    }

    public enum CodingKeys: String, CodingKey {
      case markerType, status, statusDate, position, positionSource
      case distanceFromApproachEnd, distanceFromCenterline
      case distanceSource, facilityType, locationId, name
      case frequency, collocatedNavaid, lowPoweredNDBStatus, service
    }
  }

  public enum CodingKeys: String, CodingKey {
    case airportSiteNumber, runwayEndId, systemType, ILSId, airportId
    case airportName, city, stateCode, stateName, regionCode
    case runwayLength, runwayWidth, category, owner, `operator`
    case approachBearing, magneticVariation, effectiveDate
    case localizer, glideSlope, dme, markers, remarks
  }
}
