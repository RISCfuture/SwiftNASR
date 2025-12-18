import Foundation

public extension ParachuteJumpArea {
  /// The azimuth from the navaid as a Measurement.
  var azimuthFromNavaid: Measurement<UnitAngle>? {
    azimuthFromNavaidDeg.map { Measurement(value: $0, unit: .degrees) }
  }

  /// The distance from the navaid as a Measurement.
  var distanceFromNavaid: Measurement<UnitLength>? {
    distanceFromNavaidNM.map { Measurement(value: $0, unit: .nauticalMiles) }
  }

  /// The area radius from the center point as a Measurement.
  var radius: Measurement<UnitLength>? {
    radiusNM.map { Measurement(value: $0, unit: .nauticalMiles) }
  }
}

// MARK: - ParachuteJumpArea.ContactFacility

public extension ParachuteJumpArea.ContactFacility {
  /// The commercial frequency as a Measurement.
  var commercialFrequency: Measurement<UnitFrequency>? {
    commercialFrequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }

  /// The military frequency as a Measurement.
  var militaryFrequency: Measurement<UnitFrequency>? {
    militaryFrequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }
}
