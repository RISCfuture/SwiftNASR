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

  func parseRunwayEnd(_ values: [Any?], offset1: Int, offset2: Int, airport _: Airport) throws
    -> RunwayEnd
  {
    let VGSI = try values[offset1 + 20].map { str in
      do {
        return try parseVGSI(str as! String)
      } catch {
        throw FixedWidthParserError.invalidValue(values[offset1 + 20] as! String, at: offset1 + 20)
      }
    }

    let threshold = zipOptionals(values[offset1 + 6], values[offset1 + 8]).map { lat, lon in
      Location(
        latitude: lat as! Float,
        longitude: lon as! Float,
        elevation: values[offset1 + 10] as! Float?
      )
    }
    let displacedThreshold = zipOptionals(values[offset1 + 13], values[offset1 + 15]).map {
      lat,
      lon in
      Location(
        latitude: lat as! Float,
        longitude: lon as! Float,
        elevation: values[offset1 + 17] as! Float?
      )
    }

    let gradient = try values[offset2].map { grad in
      var grad = grad as! Float
      switch values[offset2 + 1] as! String {
        case "UP": break
        case "DOWN": grad *= -1
        default: throw FixedWidthParserError.invalidValue(values[offset2] as! String, at: offset2)
      }
      return grad
    }

    let location = zipOptionals(values[offset2 + 19], values[offset2 + 21]).map { lat, lon in
      Location(
        latitude: lat as! Float,
        longitude: lon as! Float,
        elevation: nil
      )
    }

    let LAHSO = values[offset2 + 16].map { dist in
      RunwayEnd.LAHSOPoint(
        availableDistance: dist as! UInt,
        intersectingRunwayID: values[offset2 + 17] as! String?,
        definingEntity: values[offset2 + 18] as! String?,
        position: location,
        positionSource: values[offset2 + 23] as! String?,
        positionSourceDate: values[offset2 + 24] as! Date?
      )
    }

    let controllingObject = values[offset1 + 27].map { cat in
      RunwayEnd.ControllingObject(
        category: cat as! RunwayEnd.ControllingObject.Category,
        markings: values[offset1 + 28] as! [RunwayEnd.ControllingObject.Marking],
        runwayCategory: values[offset1 + 29] as! String?,
        clearanceSlope: values[offset1 + 30] as! UInt?,
        heightAboveRunway: values[offset1 + 31] as! UInt?,
        distanceFromRunway: values[offset1 + 32] as! UInt?,
        offsetFromCenterline: values[offset1 + 33] as! Offset?
      )
    }

    return RunwayEnd(
      ID: values[offset1] as! String,
      trueHeading: values[offset1 + 1] as! UInt?,
      instrumentLandingSystem: values[offset1 + 2] as! RunwayEnd.InstrumentLandingSystem?,
      rightTraffic: values[offset1 + 3] as! Bool?,
      marking: values[offset1 + 4] as! RunwayEnd.Marking?,
      markingCondition: values[offset1 + 5] as! RunwayEnd.MarkingCondition?,
      threshold: threshold,
      thresholdCrossingHeight: values[offset1 + 11] as! UInt?,
      visualGlidepath: values[offset1 + 12] as! Float?,
      displacedThreshold: displacedThreshold,
      thresholdDisplacement: values[offset1 + 18] as! UInt?,
      touchdownZoneElevation: values[offset1 + 19] as! Float?,
      gradient: gradient,
      TORA: values[offset2 + 12] as! UInt?,
      TODA: values[offset2 + 13] as! UInt?,
      ASDA: values[offset2 + 14] as! UInt?,
      LDA: values[offset2 + 15] as! UInt?,
      LAHSO: LAHSO,
      visualGlideslopeIndicator: VGSI,
      RVRSensors: values[offset1 + 21] as! [RunwayEnd.RVRSensor],
      hasRVV: values[offset1 + 22] as! Bool?,
      approachLighting: values[offset1 + 23] as! RunwayEnd.ApproachLighting?,
      hasREIL: values[offset1 + 24] as! Bool?,
      hasCenterlineLighting: values[offset1 + 25] as! Bool?,
      endTouchdownLighting: values[offset1 + 26] as! Bool?,
      controllingObject: controllingObject,
      positionSource: values[offset2 + 2] as! String?,
      positionSourceDate: values[offset2 + 3] as! Date?,
      elevationSource: values[offset2 + 4] as! String?,
      elevationSourceDate: values[offset2 + 5] as! Date?,
      displacedThresholdPositionSource: values[offset2 + 6] as! String?,
      displacedThresholdPositionSourceDate: values[offset2 + 7] as! Date?,
      displacedThresholdElevationSource: values[offset2 + 8] as! String?,
      displacedThresholdElevationSourceDate: values[offset2 + 9] as! Date?,
      touchdownZoneElevationSource: values[offset2 + 10] as! String?,
      touchdownZoneElevationSourceDate: values[offset2 + 11] as! Date?
    )
  }
}
