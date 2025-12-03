/**
 The latitude, longitude, and elevation of a point on the earth.
 */

public struct Location: Record {

  /// The latitude in arc-seconds (positive is north).
  public let latitude: Float

  /// The longitude in arc-seconds (positive is east).
  public let longitude: Float

  /// The elevation in feet (optional).
  public let elevation: Float?

  private enum CodingKeys: String, CodingKey {
    case latitude, longitude, elevation
  }
}

/**
 An offset from a location or extended centerline.
 */

public struct Offset: Record {

  /// The distance from an extended centerline, in feet.
  public let distance: UInt

  /// The direction from an extended centerline.
  public let direction: Direction

  /// Possible directions from an extended centerline.
  public enum Direction: String, Record {
    case left = "L"
    case right = "R"

    /// Both left and right of centerline (e.g., for obstancles that span
    /// accross the centerline).
    case both = "B"

    static func from(string: String) -> Self? {
      if let self = Self(rawValue: string) { return self }
      if string == "L/R" { return .both }
      return nil
    }
  }
}

/// Types of navigation aid facilities.
public enum NavaidFacilityType: String, Record {

  /// Combined VOR and TACAN facility.
  case VORTAC = "C"

  /// VOR facility with DME capability.
  case VORDME = "D"

  /// A radio marker beacon (such as an OM, IM, or MM) used for enroute
  /// navigation.
  case fanMarker = "F"

  /// A low-frequency radio range, if any of these are still around.
  case LFR = "L"

  /// An NDB intended for use by watercraft.
  case marineNDB = "M"

  /// A marine NDB with DME capability.
  case marineNDB_DME = "MD"

  /// A VOR test facility (always transmits the 360° radial signal).
  case VOT = "O"

  /// A distance measuring equipment facility for use with DME transponders.
  case DME = "OD"

  /// A non-directional beacon that transmits a radio signal that is the same
  /// in all directions.
  case NDB = "R"

  /// An NDB with DME capability.
  case NDB_DME = "RD"

  /// A tactical air navigation facility; an omnidirectional radio range used
  /// by the military (also includes DME capability).
  case TACAN = "T"

  /// An NDB that transmits on the UHF band.
  case UHF_NDB = "U"

  /// A VHF omnidirectional range; a facility that transmits a
  /// highly directional signal that can be used to determine the receiver's
  /// bearing to the station.
  case VOR = "V"
}

/**
 General (non-specific) direction of a facility or location, relative to an
 airport.
 */

public enum Direction: String, RecordEnum {
  case north = "N"
  case northNortheast = "NNE"
  case northeast = "NE"
  case eastNortheast = "ENE"
  case east = "E"
  case eastSoutheast = "ESE"
  case southeast = "SE"
  case southSoutheast = "SSE"
  case south = "S"
  case southSouthwest = "SSW"
  case southwest = "SW"
  case westSouthwest = "WSW"
  case west = "W"
  case westNorthwest = "WNW"
  case northwest = "NW"
  case northNorthwest = "NNW"
}
