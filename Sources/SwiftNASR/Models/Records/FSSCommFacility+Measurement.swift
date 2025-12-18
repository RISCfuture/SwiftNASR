import Foundation

// MARK: - FSSCommFacility.Frequency

public extension FSSCommFacility.Frequency {
  /// The radio frequency as a Measurement.
  var frequency: Measurement<UnitFrequency> {
    Measurement(value: Double(frequencyKHz), unit: .kilohertz)
  }
}
