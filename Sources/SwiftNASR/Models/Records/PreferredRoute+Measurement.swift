import Foundation

// MARK: - PreferredRoute.RadialDistance

public extension PreferredRoute.RadialDistance {
  /// The radial (bearing) from the navaid as a Measurement.
  var radial: Measurement<UnitAngle> {
    switch self {
      case .radialDeg(let deg):
        return Measurement(value: Double(deg), unit: .degrees)
      case .radialDistanceDegNM(let deg, _):
        return Measurement(value: Double(deg), unit: .degrees)
    }
  }

  /// The distance from the navaid as a Measurement, if present.
  var distance: Measurement<UnitLength>? {
    switch self {
      case .radialDeg:
        return nil
      case .radialDistanceDegNM(_, let nm):
        return Measurement(value: Double(nm), unit: .nauticalMiles)
    }
  }
}
