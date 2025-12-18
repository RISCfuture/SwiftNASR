import Foundation

// MARK: - Fix.NavaidMakeup

public extension Fix.NavaidMakeup {
  /// The radial or bearing from the navaid as a Measurement.
  var radial: Measurement<UnitAngle>? {
    radialDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }

  /// The DME distance from the navaid as a Measurement.
  var distance: Measurement<UnitLength>? {
    distanceNM.map { Measurement(value: Double($0), unit: .nauticalMiles) }
  }
}
