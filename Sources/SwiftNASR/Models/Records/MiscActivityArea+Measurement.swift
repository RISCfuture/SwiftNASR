import Foundation

public extension MiscActivityArea {
  /// The azimuth (bearing) from the navaid as a Measurement.
  var navaidAzimuth: Measurement<UnitAngle>? {
    navaidAzimuthDeg.map { Measurement(value: $0, unit: .degrees) }
  }

  /// The distance from the navaid as a Measurement.
  var navaidDistance: Measurement<UnitLength>? {
    navaidDistanceNM.map { Measurement(value: $0, unit: .nauticalMiles) }
  }

  /// The distance to the nearest airport as a Measurement.
  var nearestAirportDistance: Measurement<UnitLength>? {
    nearestAirportDistanceNM.map { Measurement(value: $0, unit: .nauticalMiles) }
  }

  /// The area radius from the center point as a Measurement.
  var areaRadius: Measurement<UnitLength>? {
    areaRadiusNM.map { Measurement(value: $0, unit: .nauticalMiles) }
  }
}

// MARK: - MiscActivityArea.ContactFacility

public extension MiscActivityArea.ContactFacility {
  /// The commercial (civil) frequency as a Measurement.
  var commercialFrequency: Measurement<UnitFrequency>? {
    commercialFrequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }

  /// The military frequency as a Measurement.
  var militaryFrequency: Measurement<UnitFrequency>? {
    militaryFrequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }
}
