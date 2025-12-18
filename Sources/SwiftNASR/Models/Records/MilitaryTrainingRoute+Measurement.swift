import Foundation

// MARK: - MilitaryTrainingRoute.RoutePoint

public extension MilitaryTrainingRoute.RoutePoint {
  /// The bearing from the point to the navaid as a Measurement.
  var navaidBearing: Measurement<UnitAngle>? {
    navaidBearingDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }

  /// The distance from the point to the navaid as a Measurement.
  var navaidDistance: Measurement<UnitLength>? {
    navaidDistanceNM.map { Measurement(value: Double($0), unit: .nauticalMiles) }
  }
}
