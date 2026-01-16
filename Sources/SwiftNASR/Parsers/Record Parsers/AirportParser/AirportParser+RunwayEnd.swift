import Foundation
@preconcurrency import RegexBuilder

private final class VGSIParser: Sendable {
  private let numberRef = Reference<UInt>()
  private let sideRef = Reference<RunwayEnd.VisualGlideslopeIndicator.Side?>()

  private var SAVASI_Rx: some RegexComponent {
    Regex {
      Anchor.startOfSubject
      "S"
      Capture(as: numberRef) {
        OneOrMore(.digit)
      } transform: {
        .init($0)!
      }
      Capture(as: sideRef) {
        .anyOf("LR")
      } transform: {
        .init(rawValue: String($0))
      }
      Anchor.endOfSubject
    }
  }

  private var VASI_Rx: some RegexComponent {
    Regex {
      Anchor.startOfSubject
      "V"
      Capture(as: numberRef) {
        OneOrMore(.digit)
      } transform: {
        UInt($0)!
      }
      Capture(as: sideRef) {
        Optionally { .anyOf("LR") }
      } transform: {
        .init(rawValue: String($0))
      }

      Anchor.endOfSubject
    }
  }

  private var largeVASI_Rx: some RegexComponent {
    Regex {
      Anchor.startOfSubject
      "V"
      Capture(as: sideRef) {
        .anyOf("LR")
      } transform: {
        .init(rawValue: String($0))
      }
      Anchor.endOfSubject
    }
  }

  private var PAPI_Rx: some RegexComponent {
    Regex {
      Anchor.startOfSubject
      "P"
      Capture(as: numberRef) {
        OneOrMore(.digit)
      } transform: {
        UInt($0)!
      }
      Capture(as: sideRef) {
        .anyOf("LR")
      } transform: {
        .init(rawValue: String($0))
      }
      Anchor.endOfSubject
    }
  }

  private var tricolorVASI_Rx: some RegexComponent {
    Regex {
      Anchor.startOfSubject
      "TRI"
      Capture(as: sideRef) {
        .anyOf("LR")
      } transform: {
        .init(rawValue: String($0))
      }
      Anchor.endOfSubject
    }
  }

  private var pulsatingVASI_Rx: some RegexComponent {
    Regex {
      Anchor.startOfSubject
      "PSI"
      Capture(as: sideRef) {
        .anyOf("LR")
      } transform: {
        .init(rawValue: String($0))
      }
      Anchor.endOfSubject
    }
  }

  private var panelsRx: some RegexComponent {
    Regex {
      Anchor.startOfSubject
      "PNI"
      Capture(as: sideRef) {
        .anyOf("LR")
      } transform: {
        .init(rawValue: String($0))
      }
      Anchor.endOfSubject
    }
  }

  func parseVGSI(_ value: String) throws -> RunwayEnd.VisualGlideslopeIndicator? {
    if let match = try SAVASI_Rx.regex.firstMatch(in: value) {
      let number = match[numberRef]
      let side = match[sideRef]
      return RunwayEnd.VisualGlideslopeIndicator(type: .SAVASI, number: number, side: side)
    }
    if let match = try VASI_Rx.regex.firstMatch(in: value) {
      let number = match[numberRef]
      let side = match[sideRef]
      return RunwayEnd.VisualGlideslopeIndicator(type: .VASI, number: number, side: side)
    }
    if let match = try largeVASI_Rx.regex.firstMatch(in: value) {
      let number = match[numberRef]
      return RunwayEnd.VisualGlideslopeIndicator(type: .VASI, number: number, side: nil)
    }
    if let match = try PAPI_Rx.regex.firstMatch(in: value) {
      let number = match[numberRef]
      let side = match[sideRef]
      return RunwayEnd.VisualGlideslopeIndicator(type: .PAPI, number: number, side: side)
    }
    if let match = try tricolorVASI_Rx.regex.firstMatch(in: value) {
      let side = match[sideRef]
      return RunwayEnd.VisualGlideslopeIndicator(type: .tricolorVASI, number: nil, side: side)
    }
    if let match = try pulsatingVASI_Rx.regex.firstMatch(in: value) {
      let side = match[sideRef]
      return RunwayEnd.VisualGlideslopeIndicator(type: .pulsatingVASI, number: nil, side: side)
    }
    if let match = try panelsRx.regex.firstMatch(in: value) {
      let side = match[sideRef]
      return RunwayEnd.VisualGlideslopeIndicator(type: .panels, number: nil, side: side)
    }
    return nil
  }
}

private let vgsiParser = VGSIParser()

extension FixedWidthAirportParser {
  private func parseVGSI(_ value: String) throws -> RunwayEnd.VisualGlideslopeIndicator {
    switch value {
      case "NSTD": return RunwayEnd.VisualGlideslopeIndicator(type: .nonstandard)
      case "PVT": return RunwayEnd.VisualGlideslopeIndicator(type: .private)
      case "VAS": return RunwayEnd.VisualGlideslopeIndicator(type: .nonspecificVASI)
      default:
        if let VGSI = try vgsiParser.parseVGSI(value) { return VGSI }
        throw Error.invalidVGSI(value)
    }
  }

  func parseRunwayEnd(_ t: FixedWidthTransformedRow, offset1: Int, offset2: Int, airport: Airport)
    throws
    -> RunwayEnd
  {
    // Extract values from offset1 block
    let runwayId: String = try t[offset1],
      headingValue: UInt? = try t[optional: offset1 + 1],
      ILS: RunwayEnd.InstrumentLandingSystem? = try t[optional: offset1 + 2],
      rightTraffic: Bool? = try t[optional: offset1 + 3],
      marking: RunwayEnd.Marking? = try t[optional: offset1 + 4],
      markingCondition: RunwayEnd.MarkingCondition? = try t[optional: offset1 + 5],
      thresholdLat: Float? = try t[optional: offset1 + 6],
      thresholdLon: Float? = try t[optional: offset1 + 8],
      thresholdElev: Float? = try t[optional: offset1 + 10],
      thresholdCrossingHeightFtAGL: UInt? = try t[optional: offset1 + 11],
      visualGlidepathDeg: Float? = try t[optional: offset1 + 12],
      displacedThresholdLat: Float? = try t[optional: offset1 + 13],
      displacedThresholdLon: Float? = try t[optional: offset1 + 15],
      displacedThresholdElev: Float? = try t[optional: offset1 + 17],
      thresholdDisplacementFt: UInt? = try t[optional: offset1 + 18],
      touchdownZoneElevationFtMSL: Float? = try t[optional: offset1 + 19],
      VGSIStr: String? = try t[optional: offset1 + 20],
      RVRSensors: [RunwayEnd.RVRSensor] = try t[offset1 + 21],
      hasRVV: Bool? = try t[optional: offset1 + 22],
      approachLighting: RunwayEnd.ApproachLighting? = try t[optional: offset1 + 23],
      hasREIL: Bool? = try t[optional: offset1 + 24],
      hasCenterlineLighting: Bool? = try t[optional: offset1 + 25],
      hasEndTouchdownLighting: Bool? = try t[optional: offset1 + 26],
      controllingObjectCategory: RunwayEnd.ControllingObject.Category? = try t[
        optional: offset1 + 27
      ],
      controllingObjectMarkings: [RunwayEnd.ControllingObject.Marking] = try t[offset1 + 28],
      controllingObjectRunwayCategory: String? = try t[optional: offset1 + 29],
      controllingObjectClearanceSlopeRatio: UInt? = try t[optional: offset1 + 30],
      controllingObjectHeightAboveRunwayFtAGL: UInt? = try t[optional: offset1 + 31],
      controllingObjectDistanceFromRunwayFt: UInt? = try t[optional: offset1 + 32],
      controllingObjectOffsetFromCenterline: Offset? = try t[optional: offset1 + 33]

    // Extract values from offset2 block
    let gradientValue: Float? = try t[optional: offset2],
      gradientDirection: String? = try t[optional: offset2 + 1],
      positionSource: String? = try t[optional: offset2 + 2],
      positionSourceDateComponents: DateComponents? = try t[optional: offset2 + 3],
      elevationSource: String? = try t[optional: offset2 + 4],
      elevationSourceDateComponents: DateComponents? = try t[optional: offset2 + 5],
      displacedThresholdPositionSource: String? = try t[optional: offset2 + 6],
      displacedThresholdPositionSourceDateComponents: DateComponents? = try t[
        optional: offset2 + 7
      ],
      displacedThresholdElevationSource: String? = try t[optional: offset2 + 8],
      displacedThresholdElevationSourceDateComponents: DateComponents? = try t[
        optional: offset2 + 9
      ],
      touchdownZoneElevationSource: String? = try t[optional: offset2 + 10],
      touchdownZoneElevationSourceDateComponents: DateComponents? = try t[optional: offset2 + 11],
      TORAFt: UInt? = try t[optional: offset2 + 12],
      TODAFt: UInt? = try t[optional: offset2 + 13],
      ASDAFt: UInt? = try t[optional: offset2 + 14],
      LDAFt: UInt? = try t[optional: offset2 + 15],
      LAHSOAvailableDistanceFt: UInt? = try t[optional: offset2 + 16],
      LAHSOIntersectingRunwayId: String? = try t[optional: offset2 + 17],
      LAHSODefiningEntity: String? = try t[optional: offset2 + 18],
      LAHSOLat: Float? = try t[optional: offset2 + 19],
      LAHSOLon: Float? = try t[optional: offset2 + 21],
      LAHSOPositionSource: String? = try t[optional: offset2 + 23],
      LAHSOPositionSourceDateComponents: DateComponents? = try t[optional: offset2 + 24]

    // Parse VGSI
    let VGSI: RunwayEnd.VisualGlideslopeIndicator?
    if let str = VGSIStr {
      do {
        VGSI = try parseVGSI(str)
      } catch {
        throw FixedWidthParserError.invalidValue(str, at: offset1 + 20)
      }
    } else {
      VGSI = nil
    }

    // Build threshold location
    let threshold = zipOptionals(thresholdLat, thresholdLon).map { lat, lon in
      Location(latitudeArcsec: lat, longitudeArcsec: lon, elevationFtMSL: thresholdElev)
    }

    // Build displaced threshold location
    let displacedThreshold = zipOptionals(displacedThresholdLat, displacedThresholdLon).map {
      lat,
      lon in
      Location(latitudeArcsec: lat, longitudeArcsec: lon, elevationFtMSL: displacedThresholdElev)
    }

    // Parse gradient
    let gradient: Float?
    if let gradValue = gradientValue {
      var grad = gradValue
      if let direction = gradientDirection {
        switch direction {
          case "UP": break
          case "DOWN": grad *= -1
          default: throw FixedWidthParserError.invalidValue(String(grad), at: offset2)
        }
      }
      gradient = grad
    } else {
      gradient = nil
    }

    // Build LAHSO location
    let LAHSOLocation = zipOptionals(LAHSOLat, LAHSOLon).map { lat, lon in
      Location(latitudeArcsec: lat, longitudeArcsec: lon)
    }

    // Build LAHSO
    let LAHSO = LAHSOAvailableDistanceFt.map { dist in
      RunwayEnd.LAHSOPoint(
        availableDistanceFt: dist,
        intersectingRunwayId: LAHSOIntersectingRunwayId,
        definingEntity: LAHSODefiningEntity,
        position: LAHSOLocation,
        positionSource: LAHSOPositionSource,
        positionSourceDateComponents: LAHSOPositionSourceDateComponents
      )
    }

    // Build controlling object
    let controllingObject = controllingObjectCategory.map { cat in
      RunwayEnd.ControllingObject(
        category: cat,
        markings: controllingObjectMarkings,
        runwayCategory: controllingObjectRunwayCategory,
        clearanceSlopeRatio: controllingObjectClearanceSlopeRatio,
        heightAboveRunwayFtAGL: controllingObjectHeightAboveRunwayFtAGL,
        distanceFromRunwayFt: controllingObjectDistanceFromRunwayFt,
        offsetFromCenterline: controllingObjectOffsetFromCenterline
      )
    }

    // Convert true heading to Bearing<UInt>
    let heading = headingValue.map { value in
      Bearing(value, reference: .true, magneticVariationDeg: airport.magneticVariationDeg ?? 0)
    }

    return RunwayEnd(
      id: runwayId,
      heading: heading,
      instrumentLandingSystem: ILS,
      rightTraffic: rightTraffic,
      marking: marking,
      markingCondition: markingCondition,
      threshold: threshold,
      thresholdCrossingHeightFtAGL: thresholdCrossingHeightFtAGL,
      visualGlidepathDeg: visualGlidepathDeg,
      displacedThreshold: displacedThreshold,
      thresholdDisplacementFt: thresholdDisplacementFt,
      touchdownZoneElevationFtMSL: touchdownZoneElevationFtMSL,
      gradientPct: gradient,
      TORAFt: TORAFt,
      TODAFt: TODAFt,
      ASDAFt: ASDAFt,
      LDAFt: LDAFt,
      LAHSO: LAHSO,
      visualGlideslopeIndicator: VGSI,
      RVRSensors: RVRSensors,
      hasRVV: hasRVV,
      approachLighting: approachLighting,
      hasREIL: hasREIL,
      hasCenterlineLighting: hasCenterlineLighting,
      hasEndTouchdownLighting: hasEndTouchdownLighting,
      controllingObject: controllingObject,
      positionSource: positionSource,
      positionSourceDateComponents: positionSourceDateComponents,
      elevationSource: elevationSource,
      elevationSourceDateComponents: elevationSourceDateComponents,
      displacedThresholdPositionSource: displacedThresholdPositionSource,
      displacedThresholdPositionSourceDateComponents:
        displacedThresholdPositionSourceDateComponents,
      displacedThresholdElevationSource: displacedThresholdElevationSource,
      displacedThresholdElevationSourceDateComponents:
        displacedThresholdElevationSourceDateComponents,
      touchdownZoneElevationSource: touchdownZoneElevationSource,
      touchdownZoneElevationSourceDateComponents: touchdownZoneElevationSourceDateComponents
    )
  }
}
