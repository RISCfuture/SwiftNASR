import CoreLocation
import Foundation

// MARK: - Location

public extension Location {
  /// The latitude as a Measurement.
  var latitude: Measurement<UnitAngle> {
    Measurement(value: Double(latitudeArcsec), unit: .arcSeconds)
  }

  /// The longitude as a Measurement.
  var longitude: Measurement<UnitAngle> {
    Measurement(value: Double(longitudeArcsec), unit: .arcSeconds)
  }

  /// The elevation as a Measurement.
  var elevation: Measurement<UnitLength>? {
    elevationFtMSL.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The coordinate as a CoreLocation coordinate.
  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(
      latitude: latitude.converted(to: .degrees).value,
      longitude: longitude.converted(to: .degrees).value
    )
  }

  /// The location as a CoreLocation location, including altitude if available.
  var location: CLLocation {
    if let elevation {
      return CLLocation(
        coordinate: coordinate,
        altitude: elevation.converted(to: .meters).value,
        horizontalAccuracy: -1,
        verticalAccuracy: -1,
        timestamp: .distantPast
      )
    }
  return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
  }
}

// MARK: - Bearing

public extension Bearing {
  /// The magnetic variation as a Measurement.
  var magneticVariation: Measurement<UnitAngle> {
    Measurement(value: Double(magneticVariationDeg), unit: .degrees)
  }
}

// MARK: - Offset

public extension Offset {
  /// The distance from an extended centerline as a Measurement.
  var distance: Measurement<UnitLength> {
    Measurement(value: Double(distanceFt), unit: .feet)
  }
}

// MARK: - TrackAnglePair

public extension TrackAnglePair {
  /// The primary track angle as a Measurement.
  var primary: Measurement<UnitAngle> {
    Measurement(value: Double(primaryDeg), unit: .degrees)
  }

  /// The reciprocal track angle as a Measurement.
  var reciprocal: Measurement<UnitAngle> {
    Measurement(value: Double(reciprocalDeg), unit: .degrees)
  }
}
