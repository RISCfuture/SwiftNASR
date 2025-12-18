import Foundation

public extension WeatherStation {
  /// The primary frequency for receiving weather broadcasts as a Measurement.
  var frequency: Measurement<UnitFrequency>? {
    frequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }

  /// The secondary frequency for receiving weather broadcasts as a Measurement.
  var secondaryFrequency: Measurement<UnitFrequency>? {
    secondaryFrequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }
}
