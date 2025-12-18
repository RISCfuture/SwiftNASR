import Foundation

public extension RunwayEnd {
  /// The height of the visual glidepath above the runway threshold as a Measurement.
  var thresholdCrossingHeight: Measurement<UnitLength>? {
    thresholdCrossingHeightFtAGL.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The glidepath angle for a visual approach as a Measurement.
  var visualGlidepath: Measurement<UnitAngle>? {
    visualGlidepathHundredthsDeg.map { Measurement(value: Double($0) / 100.0, unit: .degrees) }
  }

  /// The distance between the runway end and displaced threshold as a Measurement.
  var thresholdDisplacement: Measurement<UnitLength>? {
    thresholdDisplacementFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The highest elevation within the touchdown zone as a Measurement.
  var touchdownZoneElevation: Measurement<UnitLength>? {
    touchdownZoneElevationFtMSL.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The slope between the approach and departure ends of the runway as a Measurement.
  var gradient: Measurement<UnitSlope>? {
    gradientPct.map { Measurement(value: Double($0), unit: .percentGrade) }
  }

  /// The takeoff run available as a Measurement.
  var TORA: Measurement<UnitLength>? {
    TORAFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The takeoff distance available as a Measurement.
  var TODA: Measurement<UnitLength>? {
    TODAFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The accelerate-stop distance available as a Measurement.
  var ASDA: Measurement<UnitLength>? {
    ASDAFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The landing distance available as a Measurement.
  var LDA: Measurement<UnitLength>? {
    LDAFt.map { Measurement(value: Double($0), unit: .feet) }
  }
}

// MARK: - RunwayEnd.ControllingObject

public extension RunwayEnd.ControllingObject {
  /// Clearance slope as a Measurement (gradient).
  ///
  /// The stored value is the _x_ in _x_:1 (run:rise). This converts it to rise/run.
  var clearanceSlope: Measurement<UnitSlope>? {
    clearanceSlopeRatio.map { Measurement(value: 1.0 / Double($0), unit: .gradient) }
  }

  /// Obstacle height above runway surface as a Measurement.
  var heightAboveRunway: Measurement<UnitLength>? {
    heightAboveRunwayFtAGL.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Obstacle distance from runway threshold as a Measurement.
  var distanceFromRunway: Measurement<UnitLength>? {
    distanceFromRunwayFt.map { Measurement(value: Double($0), unit: .feet) }
  }
}

// MARK: - RunwayEnd.LAHSOPoint

public extension RunwayEnd.LAHSOPoint {
  /// The distance from the landing threshold to the LAHSO point as a Measurement.
  var availableDistance: Measurement<UnitLength> {
    Measurement(value: Double(availableDistanceFt), unit: .feet)
  }
}
