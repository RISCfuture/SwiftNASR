import Foundation

public extension Runway {
  /// The total runway length as a Measurement.
  var length: Measurement<UnitLength>? {
    lengthFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The runway width as a Measurement.
  var width: Measurement<UnitLength>? {
    widthFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The maximum weight of an aircraft with single-wheel type landing gear as a Measurement.
  var singleWheelWeightBearingCapacity: Measurement<UnitMass>? {
    singleWheelWeightBearingCapacityKlb.map {
      Measurement(value: Double($0) * 1000, unit: .pounds)
    }
  }

  /// The maximum weight of an aircraft with dual-wheel type landing gear as a Measurement.
  var dualWheelWeightBearingCapacity: Measurement<UnitMass>? {
    dualWheelWeightBearingCapacityKlb.map {
      Measurement(value: Double($0) * 1000, unit: .pounds)
    }
  }

  /// The maximum weight of an aircraft with two dual wheels in tandem type landing gear
  /// as a Measurement.
  var tandemDualWheelWeightBearingCapacity: Measurement<UnitMass>? {
    tandemDualWheelWeightBearingCapacityKlb.map {
      Measurement(value: Double($0) * 1000, unit: .pounds)
    }
  }

  /// The maximum weight of an aircraft with two dual wheels in double tandem body gear
  /// as a Measurement.
  var doubleTandemDualWheelWeightBearingCapacity: Measurement<UnitMass>? {
    doubleTandemDualWheelWeightBearingCapacityKlb.map {
      Measurement(value: Double($0) * 1000, unit: .pounds)
    }
  }

  /// The estimated runway gradient as a Measurement.
  var estimatedGradient: Measurement<UnitSlope>? {
    estimatedGradientPct.map { Measurement(value: Double($0), unit: .percentGrade) }
  }
}
