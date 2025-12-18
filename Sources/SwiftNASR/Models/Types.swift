import Foundation

// MARK: - Bearing

/**
 A bearing or heading expressed in degrees, with a known reference (true or magnetic north)
 and the ability to convert between references using magnetic variation.

 Bearings in aviation are typically expressed relative to either true north (geographic)
 or magnetic north (as indicated by a compass). The difference between these is the
 magnetic variation, which varies by location.

 - Note: The conversion formulas are:
   - Magnetic = True − Variation (where East variation is positive)
   - True = Magnetic + Variation
 */
public struct Bearing<T: Codable & Equatable & Hashable & Sendable>: Record, Equatable, Hashable,
  Sendable
{

  // MARK: - Properties

  /// The bearing value in degrees.
  public let value: T

  /// The reference (true or magnetic) of this bearing.
  public let reference: Reference

  /// The magnetic variation at the location (degrees; positive is east).
  public let magneticVariationDeg: Int

  // MARK: - Initialization

  /// Creates a bearing with a known reference and magnetic variation.
  /// - Parameters:
  ///   - value: The bearing value in degrees.
  ///   - reference: Whether the bearing is referenced to true or magnetic north.
  ///   - magneticVariationDeg: The magnetic variation at the location (degrees; east is positive).
  public init(_ value: T, reference: Reference, magneticVariationDeg: Int) {
    self.value = value
    self.reference = reference
    self.magneticVariationDeg = magneticVariationDeg
  }

  // MARK: - Nested Types

  /// The reference direction for a bearing.
  public enum Reference: Codable, Equatable, Hashable, Sendable {
    /// Referenced to true (geographic) north.
    case `true`

    /// Referenced to magnetic north.
    case magnetic
  }
}

extension Bearing where T: BinaryInteger {
  /// Returns this bearing converted to true north reference.
  ///
  /// If this bearing is already referenced to true north, returns itself unchanged.
  public func asTrueBearing() -> Bearing<T> {
    guard reference == .magnetic else { return self }
    let converted = normalize(Int(value) + magneticVariationDeg)
    return Bearing(T(converted), reference: .true, magneticVariationDeg: magneticVariationDeg)
  }

  /// Returns this bearing converted to magnetic north reference.
  ///
  /// If this bearing is already referenced to magnetic north, returns itself unchanged.
  public func asMagneticBearing() -> Bearing<T> {
    guard reference == .true else { return self }
    let converted = normalize(Int(value) - magneticVariationDeg)
    return Bearing(T(converted), reference: .magnetic, magneticVariationDeg: magneticVariationDeg)
  }

  private func normalize(_ degrees: Int) -> Int {
    var result = degrees % 360
    if result < 0 { result += 360 }
    return result
  }
}

extension Bearing where T: BinaryFloatingPoint {
  /// Returns this bearing converted to true north reference.
  ///
  /// If this bearing is already referenced to true north, returns itself unchanged.
  public func asTrueBearing() -> Bearing<T> {
    guard reference == .magnetic else { return self }
    let converted = normalize(value + T(magneticVariationDeg))
    return Bearing(converted, reference: .true, magneticVariationDeg: magneticVariationDeg)
  }

  /// Returns this bearing converted to magnetic north reference.
  ///
  /// If this bearing is already referenced to magnetic north, returns itself unchanged.
  public func asMagneticBearing() -> Bearing<T> {
    guard reference == .true else { return self }
    let converted = normalize(value - T(magneticVariationDeg))
    return Bearing(converted, reference: .magnetic, magneticVariationDeg: magneticVariationDeg)
  }

  private func normalize(_ degrees: T) -> T {
    var result = degrees.truncatingRemainder(dividingBy: 360)
    if result < 0 { result += 360 }
    return result
  }
}

// MARK: - Location

/**
 The latitude, longitude, and elevation of a point on the earth.
 */

public struct Location: Record, Equatable, Hashable, Sendable {

  /// The latitude (arc-seconds; positive is north).
  public let latitudeArcsec: Float

  /// The longitude (arc-seconds; positive is east).
  public let longitudeArcsec: Float

  /// The elevation (feet MSL).
  public let elevationFtMSL: Float?

  /// Creates a location from arc-seconds coordinates.
  public init(latitudeArcsec: Float, longitudeArcsec: Float, elevationFtMSL: Float? = nil) {
    self.latitudeArcsec = latitudeArcsec
    self.longitudeArcsec = longitudeArcsec
    self.elevationFtMSL = elevationFtMSL
  }

  /// Creates a location from decimal degrees coordinates.
  public init(latitudeDeg: Double?, longitudeDeg: Double?, elevationFtMSL: Float? = nil) {
    self.latitudeArcsec = latitudeDeg.map { Float($0 * 3600) } ?? 0
    self.longitudeArcsec = longitudeDeg.map { Float($0 * 3600) } ?? 0
    self.elevationFtMSL = elevationFtMSL
  }

  private enum CodingKeys: String, CodingKey {
    case latitudeArcsec, longitudeArcsec, elevationFtMSL
  }
}

// MARK: - Altitude

/**
 An altitude value with a reference datum.

 Altitudes in aviation are typically expressed relative to either mean sea level (MSL)
 or above ground level (AGL). This type captures both the numeric value in feet and
 the reference datum.
 */
public struct Altitude: Record, Equatable, Hashable, Sendable {

  // MARK: - Properties

  /// The altitude value in feet.
  public let value: UInt

  /// The reference datum (MSL or AGL).
  public let datum: Datum

  // MARK: - Initialization

  /// Creates an altitude with a value and datum.
  /// - Parameters:
  ///   - value: The altitude value in feet.
  ///   - datum: The reference datum (MSL or AGL).
  public init(_ value: UInt, datum: Datum) {
    self.value = value
    self.datum = datum
  }

  /// Parses an altitude from a string like "5000MSL" or "3000AGL".
  /// - Parameter string: The altitude string to parse.
  /// - Throws: `ParserError.invalidValue` if the format is invalid.
  public init(parsing string: String) throws {
    let trimmed = string.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      throw ParserError.invalidValue(string)
    }

    if trimmed.hasSuffix("MSL") {
      guard let value = UInt(trimmed.dropLast(3)) else {
        throw ParserError.invalidValue(string)
      }
      self.value = value
      self.datum = .MSL
    } else if trimmed.hasSuffix("AGL") {
      guard let value = UInt(trimmed.dropLast(3)) else {
        throw ParserError.invalidValue(string)
      }
      self.value = value
      self.datum = .AGL
    } else {
      throw ParserError.invalidValue(string)
    }
  }

  // MARK: - Nested Types

  /// The reference datum for an altitude value.
  public enum Datum: String, Record, Equatable, Hashable, Sendable {
    /// Referenced to mean sea level.
    case MSL

    /// Referenced to above ground level.
    case AGL
  }
}

/**
 A pair of track angles representing outbound and reciprocal headings.

 Used for RNAV routes where track angles are specified in format "NNN/NNN"
 (e.g., "095/275" meaning 095° outbound and 275° reciprocal).
 */
public struct TrackAnglePair: Record, Equatable, Hashable, Sendable {
  /// The primary track angle (degrees, 0-360).
  public let primaryDeg: UInt16

  /// The reciprocal track angle (degrees, 0-360).
  public let reciprocalDeg: UInt16

  public init(primaryDeg: UInt16, reciprocalDeg: UInt16) {
    self.primaryDeg = primaryDeg
    self.reciprocalDeg = reciprocalDeg
  }

  /// Parses a track angle pair from format "NNN/NNN".
  /// - Throws: `ParserError.invalidValue` if the format is invalid.
  public init(parsing string: String) throws {
    let parts = string.split(separator: "/")
    guard parts.count == 2 else {
      throw ParserError.invalidValue(string)
    }
    guard let primaryDeg = UInt16(parts[0]), primaryDeg <= 360 else {
      throw ParserError.invalidValue(string)
    }
    guard let reciprocalDeg = UInt16(parts[1]), reciprocalDeg <= 360 else {
      throw ParserError.invalidValue(string)
    }
    self.primaryDeg = primaryDeg
    self.reciprocalDeg = reciprocalDeg
  }
}

/**
 An offset from a location or extended centerline.
 */

public struct Offset: Record {

  /// The distance from an extended centerline (feet).
  public let distanceFt: UInt

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

/// A cardinal or intercardinal compass direction with "bound" suffix.
///
/// Used for airway segment direction information (e.g., MEA direction,
/// crossing direction) in the format "E BND", "NE BND", etc.
public enum BoundDirection: String, RecordEnum {
  case north = "N BND"
  case northeast = "NE BND"
  case east = "E BND"
  case southeast = "SE BND"
  case south = "S BND"
  case southwest = "SW BND"
  case west = "W BND"
  case northwest = "NW BND"
}

/// Standard US time zones as used in NASR data.
///
/// NASR data uses 2-character abbreviations for US time zones.
public enum StandardTimeZone: String, RecordEnum {

  /// Eastern Time (UTC-5 / UTC-4 DST)
  case eastern = "ET"

  /// Central Time (UTC-6 / UTC-5 DST)
  case central = "CT"

  /// Mountain Time (UTC-7 / UTC-6 DST)
  case mountain = "MT"

  /// Pacific Time (UTC-8 / UTC-7 DST)
  case pacific = "PT"

  /// Alaska Time (UTC-9 / UTC-8 DST)
  case alaska = "AK"

  /// Hawaii-Aleutian Time (UTC-10)
  case hawaiiAleutian = "HT"

  /// Atlantic Time (UTC-4 / UTC-3 DST) - Puerto Rico, Virgin Islands
  case atlantic = "AT"

  /// Samoa Time (UTC-11)
  case samoa = "ST"

  /// Chamorro Time (UTC+10) - Guam, Northern Mariana Islands
  case chamorro = "ChT"

  /// The Foundation `TimeZone` corresponding to this standard time zone.
  public var foundationTimeZone: TimeZone {
    switch self {
      case .eastern: return TimeZone(identifier: "America/New_York")!
      case .central: return TimeZone(identifier: "America/Chicago")!
      case .mountain: return TimeZone(identifier: "America/Denver")!
      case .pacific: return TimeZone(identifier: "America/Los_Angeles")!
      case .alaska: return TimeZone(identifier: "America/Anchorage")!
      case .hawaiiAleutian: return TimeZone(identifier: "Pacific/Honolulu")!
      case .atlantic: return TimeZone(identifier: "America/Puerto_Rico")!
      case .samoa: return TimeZone(identifier: "Pacific/Pago_Pago")!
      case .chamorro: return TimeZone(identifier: "Pacific/Guam")!
    }
  }
}

// MARK: - ILSFacilityType

/// Types of ILS/MLS facilities used for precision approach guidance.
///
/// Used to identify the type of ILS or MLS facility providing course/azimuth
/// information for holding patterns and fix definitions.
public enum ILSFacilityType: String, RecordEnum {

  /// LDA with Distance Measuring Equipment.
  case LDA_DME = "DD"

  /// Localizer-Type Directional Aid.
  case LDA = "LA"

  /// Localizer only.
  case localizer = "LC"

  /// ILS with Distance Measuring Equipment.
  case ILS_DME = "LD"

  /// Localizer with Distance Measuring Equipment.
  case LOC_DME = "LE"

  /// Localizer with Glide Slope.
  case LOC_GS = "LG"

  /// Standard Instrument Landing System.
  case ILS = "LS"

  /// Microwave Landing System.
  case MLS = "ML"

  /// Simplified Directional Facility with DME.
  case SDF_DME = "SD"

  /// Simplified Directional Facility.
  case SDF = "SF"
}

// MARK: - SurveyMethod

/// Methods for determining geographic positions.
///
/// Indicates whether a location was precisely surveyed or estimated.
public enum SurveyMethod: String, RecordEnum {

  /// Location was estimated.
  case estimated = "E"

  /// Location was surveyed.
  case surveyed = "S"
}

// MARK: - OperationalStatus

/// The operational status of a navigation facility.
///
/// Indicates whether a navaid, ILS, or similar facility is fully operational,
/// restricted, or no longer in service.
public enum OperationalStatus: String, RecordEnum {

  /// Fully operational for IFR flight.
  case operationalIFR = "OPERATIONAL IFR"

  /// Operational for VFR only.
  case operationalVFROnly = "OPERATIONAL VFR ONLY"

  /// Operational with restrictions.
  case operationalRestricted = "OPERATIONAL RESTRICTED"

  /// Facility has been decommissioned.
  case decommissioned = "DECOMMISSIONED"

  /// Facility is temporarily shut down.
  case shutdown = "SHUTDOWN"
}

// MARK: - LateralDirection

/// Lateral direction relative to a reference (left or right).
///
/// Used for turn directions in holding patterns and lateral offsets
/// from runway centerlines.
public enum LateralDirection: String, RecordEnum {

  /// Left of the reference.
  case left = "L"

  /// Right of the reference.
  case right = "R"
}

// MARK: - CardinalDirection

/// Cardinal and intercardinal compass directions (8 directions).
///
/// Represents the eight principal compass points: the four cardinal
/// directions (N, E, S, W) and four intercardinal directions (NE, SE, SW, NW).
public enum CardinalDirection: String, RecordEnum {
  case north = "N"
  case northeast = "NE"
  case east = "E"
  case southeast = "SE"
  case south = "S"
  case southwest = "SW"
  case west = "W"
  case northwest = "NW"
}

// MARK: - FieldRemark

/// A remark associated with a specific field or general information.
///
/// Remarks provide additional context about a record, either tied to a
/// specific field (identified by fieldLabel) or as general information.
public struct FieldRemark: Record {

  /// The field label for the remark (or "GENERAL" for general remarks).
  public let fieldLabel: String

  /// The remark text.
  public let text: String

  public init(fieldLabel: String, text: String) {
    self.fieldLabel = fieldLabel
    self.text = text
  }
}
