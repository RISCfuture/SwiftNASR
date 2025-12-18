import Foundation

// MARK: - ATSAirway.RoutePoint

public extension ATSAirway.RoutePoint {
  /// The minimum reception altitude as a Measurement.
  var minimumReceptionAltitude: Measurement<UnitLength>? {
    minimumReceptionAltitudeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The distance to the changeover point as a Measurement.
  var distanceToChangeoverPoint: Measurement<UnitLength>? {
    distanceToChangeoverPointNM.map { Measurement(value: Double($0), unit: .nauticalMiles) }
  }

  /// The distance to the next point as a Measurement.
  var distanceToNextPoint: Measurement<UnitLength>? {
    distanceToNextPointNM.map { Measurement(value: $0, unit: .nauticalMiles) }
  }

  /// The minimum enroute altitude as a Measurement.
  var minimumEnrouteAltitude: Measurement<UnitLength>? {
    minimumEnrouteAltitudeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The MEA in the opposite direction as a Measurement.
  var MEAOppositeAltitude: Measurement<UnitLength>? {
    MEAOppositeAltitudeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The maximum authorized altitude as a Measurement.
  var maximumAuthorizedAltitude: Measurement<UnitLength>? {
    maximumAuthorizedAltitudeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The minimum obstruction clearance altitude as a Measurement.
  var minimumObstructionClearanceAltitude: Measurement<UnitLength>? {
    minimumObstructionClearanceAltitudeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The distance to the changeover point for the next navaid as a Measurement.
  var changeoverPointDistance: Measurement<UnitLength>? {
    changeoverPointDistanceNM.map { Measurement(value: Double($0), unit: .nauticalMiles) }
  }

  /// The minimum crossing altitude as a Measurement.
  var minimumCrossingAltitude: Measurement<UnitLength>? {
    minimumCrossingAltitudeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The minimum crossing altitude in the opposite direction as a Measurement.
  var crossingAltitudeOpposite: Measurement<UnitLength>? {
    crossingAltitudeOppositeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The variation between magnetic and true north as a Measurement.
  var magneticVariation: Measurement<UnitAngle>? {
    magneticVariationDeg.map { Measurement(value: Double($0), unit: .degrees) }
  }

  /// The GNSS MEA as a Measurement.
  var GNSS_MEA: Measurement<UnitLength>? {
    GNSS_MEAFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The GNSS MEA in the opposite direction as a Measurement.
  var GNSS_MEAOpposite: Measurement<UnitLength>? {
    GNSS_MEAOppositeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The DME/DME/IRU MEA as a Measurement.
  var DME_DME_IRU_MEA: Measurement<UnitLength>? {
    DME_DME_IRU_MEAFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The DME/DME/IRU MEA in the opposite direction as a Measurement.
  var DME_DME_IRU_MEAOpposite: Measurement<UnitLength>? {
    DME_DME_IRU_MEAOppositeFt.map { Measurement(value: Double($0), unit: .feet) }
  }

  /// The Required Navigation Performance as a Measurement.
  var RNP: Measurement<UnitLength>? {
    RNP_NM.map { Measurement(value: $0, unit: .nauticalMiles) }
  }
}
