import Foundation

public extension Airport {
  /// The variation between magnetic and true north as a Measurement.
  var magneticVariation: Measurement<UnitAngle>? {
    magneticVariationDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }

  /// The traffic pattern altitude above ground level as a Measurement.
  var trafficPatternAltitude: Measurement<UnitLength>? {
    trafficPatternAltitudeFtAGL.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The distance from the airport to the associated city as a Measurement.
  var distanceCityToAirport: Measurement<UnitLength>? {
    distanceCityToAirportNM.map { Measurement(value: Double($0), unit: .nauticalMiles) }
  }

  /// The area of land occupied by this airport as a Measurement.
  var landArea: Measurement<UnitArea>? {
    landAreaAcres.map { Measurement(value: Double($0), unit: .acres) }
  }

  /// The UNICOM frequency as a Measurement.
  var UNICOMFrequency: Measurement<UnitFrequency>? {
    UNICOMFrequencyKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }

  /// The common traffic advisory frequency as a Measurement.
  var CTAF: Measurement<UnitFrequency>? {
    CTAFKHz.map { Measurement(value: Double($0), unit: .kilohertz) }
  }
}
