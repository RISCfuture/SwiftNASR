import Foundation

/// A published holding pattern.
///
/// Holding patterns are depicted on instrument approach charts, en route charts,
/// and SID/STAR charts. They specify a holding fix, direction of turns, inbound
/// course, leg length/time, and altitude constraints.
public struct Hold: Record, Identifiable {

  // MARK: - Properties

  /// Holding pattern name (navaid or fix name with type and state code).
  public let name: String

  /// Pattern number to uniquely identify holding pattern.
  public let patternNumber: UInt

  /// Effective date of the holding pattern.
  public let effectiveDate: DateComponents?

  /// Direction of holding on the navaid or fix.
  public let holdingDirection: CardinalDirection?

  /// Magnetic bearing or radial of holding (degrees).
  public let magneticBearing: UInt?

  /// Type of azimuth (radial, course, bearing, or RNAV track).
  public let azimuthType: AzimuthType?

  /// Identifier of ILS facility used to provide course for holding.
  public let ILSFacilityIdentifier: String?

  /// Type of ILS/MLS facility.
  public let ilsFacilityType: ILSFacilityType?

  /// Identifier of navaid facility used to provide radial/bearing for holding.
  public let navaidIdentifier: String?

  /// Type of navaid facility.
  public let navaidFacilityType: Navaid.FacilityType?

  /// Additional facility used in holding pattern make-up.
  public let additionalFacility: String?

  /// Inbound course (degrees).
  public let inboundCourse: UInt?

  /// Turn direction (left or right).
  public let turnDirection: LateralDirection?

  /// Holding altitudes by aircraft airspeed category.
  public let altitudes: HoldingAltitudes

  /// Fix identifier with which holding is associated.
  public let fixIdentifier: String?

  /// Fix state code.
  public let fixStateCode: String?

  /// Fix ICAO region code.
  public let fixICAORegion: String?

  /// ARTCC associated with fix.
  public let fixARTCC: String?

  /// Position of the associated fix.
  public let fixPosition: Location?

  /// High route ARTCC associated with navaid.
  public let navaidHighRouteARTCC: String?

  /// Low route ARTCC associated with navaid.
  public let navaidLowRouteARTCC: String?

  /// Position of the associated navaid.
  public let navaidPosition: Location?

  /// Outbound leg time (minutes).
  public let legTime: Double?

  /// Outbound leg distance (nautical miles).
  public let legDistance: Double?

  /// Charting information for this hold.
  public internal(set) var chartingInfo = [String]()

  /// Other altitude/speed information.
  public internal(set) var otherAltitudeSpeed = [String]()

  /// Remarks text.
  public internal(set) var remarks = [FieldRemark]()

  public var id: String {
    "\(name)-\(patternNumber)"
  }

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  // MARK: - Types

  /// Type of azimuth/course for the holding pattern.
  public enum AzimuthType: String, RecordEnum {
    case radial = "RAD"
    case course = "CRS"
    case bearing = "BRG"
    case rnavTrack = "RNAV"
  }

  public enum CodingKeys: String, CodingKey {
    case name, patternNumber, effectiveDate, holdingDirection, magneticBearing
    case azimuthType, ILSFacilityIdentifier, ilsFacilityType
    case navaidIdentifier, navaidFacilityType, additionalFacility
    case inboundCourse, turnDirection, altitudes
    case fixIdentifier, fixStateCode, fixICAORegion, fixARTCC
    case fixPosition
    case navaidHighRouteARTCC, navaidLowRouteARTCC, navaidPosition
    case legTime, legDistance
    case chartingInfo, otherAltitudeSpeed, remarks
  }
}

/// Holding altitudes categorized by aircraft airspeed.
///
/// Different aircraft speeds require different holding altitudes to maintain
/// safe separation and pattern geometry. This struct provides lookup by airspeed
/// and access to the full dataset of defined altitudes.
///
/// Altitude values are stored as ranges in feet (e.g., `18000...45000` for FL180-FL450).
public struct HoldingAltitudes: Record {

  // MARK: - Type Properties

  private static let range170to175: ClosedRange<UInt> = 170...175
  private static let range200to230: ClosedRange<UInt> = 200...230
  private static let range265: ClosedRange<UInt> = 265...265
  private static let range280: ClosedRange<UInt> = 280...280
  private static let range310: ClosedRange<UInt> = 310...310

  // MARK: - Instance Properties

  private let _allAircraft: ClosedRange<UInt>?
  private let _170to175kt: ClosedRange<UInt>?
  private let _200to230kt: ClosedRange<UInt>?
  private let _265kt: ClosedRange<UInt>?
  private let _280kt: ClosedRange<UInt>?
  private let _310kt: ClosedRange<UInt>?

  /// The holding altitude range (in feet) that applies to all aircraft regardless of speed.
  public var allAircraftAltitude: ClosedRange<UInt>? { _allAircraft }

  // MARK: - Initialization

  /// Creates holding altitudes from the individual altitude strings.
  ///
  /// Altitude strings are in the format "min/max" where values are in hundreds of feet
  /// (e.g., "180/450" means FL180 to FL450, or 18000 to 45000 feet).
  ///
  /// - Throws: ``Error/invalidAltitudeFormat(_:)`` if a non-empty altitude string
  ///   cannot be parsed.
  public init(
    allAircraft: String?,
    speed170to175kt: String?,
    speed200to230kt: String?,
    speed265kt: String?,
    speed280kt: String?,
    speed310kt: String?
  ) throws {
    self._allAircraft = try Self.parseAltitude(allAircraft)
    self._170to175kt = try Self.parseAltitude(speed170to175kt)
    self._200to230kt = try Self.parseAltitude(speed200to230kt)
    self._265kt = try Self.parseAltitude(speed265kt)
    self._280kt = try Self.parseAltitude(speed280kt)
    self._310kt = try Self.parseAltitude(speed310kt)
  }

  // MARK: - Type Methods

  /// Parses an altitude string like "180/450" into a range in feet.
  ///
  /// Supported formats:
  /// - "180/450" or "180-450" - explicit range with separator
  /// - "200" - single value (treated as min = max)
  /// - "085140" - 6-digit concatenated range without separator (085/140)
  ///
  /// - Throws: ``Error/invalidAltitudeFormat(_:)`` if the string is non-empty
  ///   but cannot be parsed.
  private static func parseAltitude(_ string: String?) throws -> ClosedRange<UInt>? {
    guard let string, !string.isEmpty else { return nil }

    // Try "/" separator first, then "-"
    if string.contains("/") || string.contains("-") {
      let separator: Character = string.contains("/") ? "/" : "-"
      let parts = string.split(separator: separator)

      guard parts.count == 2,
        let first = UInt(parts[0]),
        let second = UInt(parts[1])
      else {
        throw Error.invalidAltitudeFormat(string)
      }

      // Ensure min <= max (swap if needed)
      let min = Swift.min(first, second)
      let max = Swift.max(first, second)

      // Convert from hundreds of feet to feet
      return (min * 100)...(max * 100)
    }

    // Single numeric value (treat as fixed altitude, min = max)
    if let value = UInt(string) {
      return (value * 100)...(value * 100)
    }

    // Try to parse 6-digit values as concatenated range (e.g., "085140" = "085/140")
    if string.count == 6, string.allSatisfy(\.isNumber) {
      let midIndex = string.index(string.startIndex, offsetBy: 3)
      if let first = UInt(string[..<midIndex]),
        let second = UInt(string[midIndex...])
      {
        let min = Swift.min(first, second)
        let max = Swift.max(first, second)
        return (min * 100)...(max * 100)
      }
    }

    throw Error.invalidAltitudeFormat(string)
  }

  // MARK: - Instance Methods

  /// Returns the holding altitude range for a given airspeed in knots.
  ///
  /// This method first checks for a specific altitude defined for the given
  /// airspeed range. If no specific altitude is defined for that airspeed,
  /// it returns the "all aircraft" altitude as a fallback.
  ///
  /// - Parameter knots: The aircraft airspeed in knots.
  /// - Returns: The appropriate holding altitude range in feet, or nil if no altitude is defined.
  public func altitude(forAirspeed knots: UInt) -> ClosedRange<UInt>? {
    if Self.range170to175.contains(knots), let alt = _170to175kt {
      return alt
    }
    if Self.range200to230.contains(knots), let alt = _200to230kt {
      return alt
    }
    if Self.range265.contains(knots), let alt = _265kt {
      return alt
    }
    if Self.range280.contains(knots), let alt = _280kt {
      return alt
    }
    if Self.range310.contains(knots), let alt = _310kt {
      return alt
    }
    return _allAircraft
  }

  /// Returns all defined speed-specific holding altitudes.
  ///
  /// This does not include the "all aircraft" altitude, which is available
  /// via ``allAircraftAltitude``.
  ///
  /// - Returns: A set of entries containing airspeed ranges and their altitude ranges.
  public func entries() -> Set<Entry> {
    var result = Set<Entry>()
    if let alt = _170to175kt {
      result.insert(Entry(airspeed: Self.range170to175, altitude: alt))
    }
    if let alt = _200to230kt {
      result.insert(Entry(airspeed: Self.range200to230, altitude: alt))
    }
    if let alt = _265kt {
      result.insert(Entry(airspeed: Self.range265, altitude: alt))
    }
    if let alt = _280kt {
      result.insert(Entry(airspeed: Self.range280, altitude: alt))
    }
    if let alt = _310kt {
      result.insert(Entry(airspeed: Self.range310, altitude: alt))
    }
    return result
  }

  // MARK: - Nested Types

  /// A holding altitude entry for a specific airspeed range.
  public struct Entry: Hashable, Sendable {
    /// The airspeed range in knots for this altitude.
    public let airspeed: ClosedRange<UInt>

    /// The holding altitude range in feet.
    public let altitude: ClosedRange<UInt>
  }

  public enum CodingKeys: String, CodingKey {
    case _allAircraft = "allAircraft"
    case _170to175kt = "speed170to175kt"
    case _200to230kt = "speed200to230kt"
    case _265kt = "speed265kt"
    case _280kt = "speed280kt"
    case _310kt = "speed310kt"
  }
}
