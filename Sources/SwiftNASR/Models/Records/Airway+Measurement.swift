import Foundation

// MARK: - Airway.Point

public extension Airway.Point {
  /// The minimum reception altitude as a Measurement.
  var minimumReceptionAltitude: Measurement<UnitLength>? {
    minimumReceptionAltitudeFt.map { Measurement(value: Double($0), unit: .feet) }
  }
}

// MARK: - Airway.Segment

public extension Airway.Segment {
  /// The distance to the next point as a Measurement.
  var distanceToNext: Measurement<UnitLength>? {
    distanceToNextNM.map { Measurement(value: Double($0), unit: .nauticalMiles) }
  }

  /// The magnetic course of the segment as a Measurement.
  var magneticCourse: Measurement<UnitAngle>? {
    magneticCourseDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }

  /// The magnetic course in the opposite direction as a Measurement.
  var magneticCourseOpposite: Measurement<UnitAngle>? {
    magneticCourseOppositeDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }
}

// MARK: - Airway.ChangeoverPoint

public extension Airway.ChangeoverPoint {
  /// Distance to the changeover point as a Measurement.
  var distance: Measurement<UnitLength>? {
    distanceNM.map { Measurement(value: Double($0), unit: .nauticalMiles) }
  }
}

// MARK: - Airway.SegmentAltitudes

public extension Airway.SegmentAltitudes {
  /// Minimum Enroute Altitude as a Measurement.
  var MEA: Measurement<UnitLength>? {
    MEAFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// MEA in opposite direction as a Measurement.
  var MEAOpposite: Measurement<UnitLength>? {
    MEAOppositeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Maximum Authorized Altitude as a Measurement.
  var MAA: Measurement<UnitLength>? {
    MAAFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Minimum Obstruction Clearance Altitude as a Measurement.
  var MOCA: Measurement<UnitLength>? {
    MOCAFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// Minimum Crossing Altitude as a Measurement.
  var MCA: Measurement<UnitLength>? {
    MCAFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// MCA in opposite direction as a Measurement.
  var MCAOpposite: Measurement<UnitLength>? {
    MCAOppositeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// GNSS MEA as a Measurement.
  var GNSS_MEA: Measurement<UnitLength>? {
    GNSS_MEAFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// GNSS MEA in opposite direction as a Measurement.
  var GNSS_MEAOpposite: Measurement<UnitLength>? {
    GNSS_MEAOppositeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// DME/DME/IRU MEA as a Measurement.
  var DME_MEA: Measurement<UnitLength>? {
    DME_MEAFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// DME/DME/IRU MEA in opposite direction as a Measurement.
  var DME_MEAOpposite: Measurement<UnitLength>? {
    DME_MEAOppositeFt.map { Measurement(value: Double($0), unit: .feet) }
  }
}
