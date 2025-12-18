import Foundation

public extension Navaid {
  /// The magnetic variation at the location of the navaid as a Measurement.
  var magneticVariation: Measurement<UnitAngle>? {
    magneticVariationDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }

  /// The power output of the navaid transmitter as a Measurement.
  var powerOutput: Measurement<UnitPower>? {
    powerOutputW.map { Measurement(value: Double($0), unit: .watts) }
  }

  /// The frequency that this navaid transmits on as a Measurement.
  var frequency: Measurement<UnitFrequency>? {
    frequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }
}

// MARK: - VORCheckpoint

public extension VORCheckpoint {
  /// The altitude of the checkpoint as a Measurement.
  var altitude: Measurement<UnitLength>? {
    altitudeFtMSL.map { Measurement(value: Double($0), unit: .feet) }
  }
}
