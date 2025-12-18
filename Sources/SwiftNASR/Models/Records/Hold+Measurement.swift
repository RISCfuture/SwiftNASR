import Foundation

public extension Hold {
  /// The magnetic bearing or radial of holding as a Measurement.
  var magneticBearing: Measurement<UnitAngle>? {
    magneticBearingDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }

  /// The inbound course as a Measurement.
  var inboundCourse: Measurement<UnitAngle>? {
    inboundCourseDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }

  /// The outbound leg time as a Measurement.
  var legTime: Measurement<UnitDuration>? {
    legTimeMin.map { Measurement(value: $0, unit: .minutes) }
  }

  /// The outbound leg distance as a Measurement.
  var legDistance: Measurement<UnitLength>? {
    legDistanceNM.map { Measurement(value: $0, unit: .nauticalMiles) }
  }
}
