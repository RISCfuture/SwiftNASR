import Foundation

// MARK: - FSS.Frequency

public extension FSS.Frequency {
  /// The radio frequency as a Measurement.
  var frequency: Measurement<UnitFrequency> {
    Measurement(value: Double(frequencyKHz), unit: .kilohertz)
  }
}
