import Foundation

// MARK: - TerminalCommFacility.Frequency

public extension TerminalCommFacility.Frequency {
  /// The frequency as a Measurement.
  var frequency: Measurement<UnitFrequency> {
    Measurement(value: Double(frequencyKHz), unit: .kilohertz)
  }
}

// MARK: - TerminalCommFacility.SatelliteAirport

public extension TerminalCommFacility.SatelliteAirport {
  /// The frequency for the satellite airport as a Measurement.
  var frequency: Measurement<UnitFrequency>? {
    frequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }
}
