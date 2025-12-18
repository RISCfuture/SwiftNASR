import Foundation

public extension ILS {
  /// The runway length as a Measurement.
  var runwayLength: Measurement<UnitLength>? {
    runwayLengthFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The runway width as a Measurement.
  var runwayWidth: Measurement<UnitLength>? {
    runwayWidthFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The variation between magnetic and true north as a Measurement.
  var magneticVariation: Measurement<UnitAngle>? {
    magneticVariationDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }
}

// MARK: - ILS.Localizer

public extension ILS.Localizer {
  /// Distance from approach end of runway as a Measurement.
  var distanceFromApproachEnd: Measurement<UnitLength>? {
    distanceFromApproachEndFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Distance from runway centerline as a Measurement.
  var distanceFromCenterline: Measurement<UnitLength>? {
    distanceFromCenterlineFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Localizer frequency as a Measurement.
  var frequency: Measurement<UnitFrequency>? {
    frequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }

  /// Course width as a Measurement.
  var courseWidth: Measurement<UnitAngle>? {
    courseWidthDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }

  /// Course width at threshold as a Measurement.
  var courseWidthAtThreshold: Measurement<UnitAngle>? {
    courseWidthAtThresholdDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }

  /// Distance from stop end of runway as a Measurement.
  var distanceFromStopEnd: Measurement<UnitLength>? {
    distanceFromStopEndFt.map { Measurement(value: Double($0), unit: .feet) }
  }
}

// MARK: - ILS.GlideSlope

public extension ILS.GlideSlope {
  /// Distance from approach end of runway as a Measurement.
  var distanceFromApproachEnd: Measurement<UnitLength>? {
    distanceFromApproachEndFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Distance from runway centerline as a Measurement.
  var distanceFromCenterline: Measurement<UnitLength>? {
    distanceFromCenterlineFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Glide slope angle as a Measurement.
  var angle: Measurement<UnitAngle>? {
    angleDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }

  /// Glide slope transmission frequency as a Measurement.
  var frequency: Measurement<UnitFrequency>? {
    frequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }

  /// Elevation of runway adjacent to glide slope antenna as a Measurement.
  var adjacentRunwayElevation: Measurement<UnitLength>? {
    adjacentRunwayElevationFtMSL.map { Measurement(value: Double($0), unit: .feet) }
  }
}

// MARK: - ILS.DME

public extension ILS.DME {
  /// Distance from approach end of runway as a Measurement.
  var distanceFromApproachEnd: Measurement<UnitLength>? {
    distanceFromApproachEndFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Distance from runway centerline as a Measurement.
  var distanceFromCenterline: Measurement<UnitLength>? {
    distanceFromCenterlineFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Distance from stop end of runway as a Measurement.
  var distanceFromStopEnd: Measurement<UnitLength>? {
    distanceFromStopEndFt.map { Measurement(value: Double($0), unit: .feet) }
  }
}

// MARK: - ILS.MarkerBeacon

public extension ILS.MarkerBeacon {
  /// Distance from approach end of runway as a Measurement.
  var distanceFromApproachEnd: Measurement<UnitLength>? {
    distanceFromApproachEndFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Distance from runway centerline as a Measurement.
  var distanceFromCenterline: Measurement<UnitLength>? {
    distanceFromCenterlineFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Frequency of locator beacon as a Measurement.
  var frequency: Measurement<UnitFrequency>? {
    frequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }
}
