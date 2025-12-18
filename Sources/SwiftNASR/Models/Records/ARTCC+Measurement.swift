import Foundation

// MARK: - ARTCC.CommFrequency

public extension ARTCC.CommFrequency {
  /// The radio frequency as a Measurement.
  var frequency: Measurement<UnitFrequency> {
    Measurement(value: Double(frequencyKHz), unit: .kilohertz)
  }
}
