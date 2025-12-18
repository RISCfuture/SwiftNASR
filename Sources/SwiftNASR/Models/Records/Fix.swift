import Foundation

/// A reporting point (fix) used for navigation and ATC communications.
///
/// Fixes are named geographic locations used for instrument flight routes and procedures.
/// They can be defined by the intersection of VOR radials, by DME distances, or by
/// GPS coordinates.
public struct Fix: ParentRecord {

  /// The fix identifier (e.g., "BOSCO", "CANOE").
  public let id: String

  /// The state (or region) where the fix is located.
  public let stateName: String

  /// The ICAO region code.
  public let ICAORegion: String?

  /// The geographic position of the fix.
  public let position: Location

  /// Whether this is a military or civil fix.
  public let category: Category

  /// The description based on a navaid/course makeup (e.g., "ABC*V*090" for ABC VOR radial 090).
  public let navaidDescription: String?

  /// The description based on a radar/airport component.
  public let radarDescription: String?

  /// The previous name of the fix if it was renamed.
  public let previousName: String?

  /// The charting information for this fix.
  public let chartingInfo: String?

  /// Whether this fix is to be published.
  public let isPublished: Bool

  /// The usage category of the fix.
  public let use: Use?

  /// The National Airspace System (NAS) identifier, usually 5 characters.
  public let NASId: String?

  /// The ARTCC with high-altitude jurisdiction over this fix.
  let highARTCCCode: String?

  /// The ARTCC with low-altitude jurisdiction over this fix.
  let lowARTCCCode: String?

  /// The country name for fixes outside CONUS.
  public let country: String?

  /// True if this fix is used as a pitch point for the High Altitude Redesign.
  public let isPitchPoint: Bool?

  /// True if this fix is used as a catch point for the High Altitude Redesign.
  public let isCatchPoint: Bool?

  /// True if this fix is associated with special-use airspace or ATCAA.
  public let isAssociatedWithSUA: Bool?

  /// Navaid makeups defining this fix (from FIX2 records).
  public internal(set) var navaidMakeups = [NavaidMakeup]()

  /// ILS makeups defining this fix (from FIX3 records).
  public internal(set) var ILSMakeups = [ILSMakeup]()

  /// Remarks associated with this fix.
  public internal(set) var remarks = [FieldRemark]()

  /// Chart types on which this fix is depicted.
  public internal(set) var chartTypes = Set<String>()

  weak var data: NASRData?

  /// Categories for fixes.
  public enum Category: String, RecordEnum {
    /// A military fix.
    case military = "MIL"

    /// A civil fix.
    case civil = "FIX"
  }

  /// Usage categories for fixes.
  public enum Use: String, RecordEnum {
    /// Computer navigation fix.
    case computerNavigationFix = "CNF"

    /// Military reporting point.
    case militaryReportingPoint = "MIL-REP-PT"

    /// Military waypoint.
    case militaryWaypoint = "MIL-WAYPOINT"

    /// NRS waypoint.
    case NRSWaypoint = "NRS-WAYPOINT"

    /// Radar fix.
    case radar = "RADAR"

    /// Reporting point.
    case reportingPoint = "REP-PT"

    /// VFR waypoint.
    case VFRWaypoint = "VFR-WP"

    /// Waypoint.
    case waypoint = "WAYPOINT"

    // Obsolete fix uses (included for backward compatibility with older data)

    /// ARTCC boundary fix (obsolete).
    case ARTCCBoundary = "ARTCC-BDRY"

    /// Airway intersection (obsolete).
    case airwayIntersection = "AWY-INTXN"

    /// Bearing intersection (obsolete).
    case bearingIntersection = "BRG-INTXN"

    /// ATC coordination fix (obsolete).
    case coordinationFix = "COORDN-FIX"

    /// DME fix (obsolete).
    case DMEFix = "DME-FIX"

    /// DP transition crossing (obsolete).
    case DPTransitionCrossing = "DP-TRANS-XING"

    /// GPS waypoint (obsolete).
    case GPSWaypoint = "GPS-WP"

    /// RNAV waypoint (obsolete).
    case RNAVWaypoint = "RNAV-WP"

    /// STAR transition crossing (obsolete).
    case STARTransitionCrossing = "STAR-TRANS-XING"

    /// Transition intersection (obsolete).
    case transitionIntersection = "TRANS-INTXN"

    /// Turning point (obsolete).
    case turningPoint = "TURN-PT"
  }

  /// A navaid-based makeup that defines the fix.
  public struct NavaidMakeup: Record {
    /// The navaid identifier.
    public let navaidId: String

    /// The navaid type code.
    public let navaidType: Navaid.FacilityType

    /// The radial or bearing from the navaid (degrees).
    public let radialDeg: UInt?

    /// The DME distance from the navaid (nautical miles).
    public let distanceNM: Float?

    /// Raw description string (e.g., "ABC*V*090/12.5").
    public let rawDescription: String

    public enum CodingKeys: String, CodingKey {
      case navaidId, navaidType, radialDeg, distanceNM, rawDescription
    }
  }

  /// An ILS-based makeup that defines the fix.
  public struct ILSMakeup: Record {
    /// The ILS identifier.
    public let ILSId: String

    /// The ILS type code.
    public let ILSType: ILSFacilityType

    /// The direction or course value.
    public let direction: String?

    /// Raw description string.
    public let rawDescription: String

    public enum CodingKeys: String, CodingKey {
      case ILSId, ILSType, direction, rawDescription
    }
  }

  public enum CodingKeys: String, CodingKey {
    case id, stateName, ICAORegion, position, category
    case navaidDescription, radarDescription, previousName, chartingInfo
    case isPublished, use, NASId, highARTCCCode, lowARTCCCode, country
    case isPitchPoint, isCatchPoint, isAssociatedWithSUA
    case navaidMakeups, ILSMakeups, remarks, chartTypes
  }
}
