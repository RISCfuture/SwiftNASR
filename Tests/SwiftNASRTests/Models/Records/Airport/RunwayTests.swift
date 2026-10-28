import Testing

@testable import SwiftNASR

@Suite
struct RunwayTests {
  @Test(
    arguments: [
      ([.asphalt, .concrete], false, true),
      ([.asphalt, .turf], false, false),
      ([.turf], true, false),
      ([.asphalt], true, nil),
      ([], false, nil)
    ] as [([Runway.Material], Bool, Bool?)]
  )
  func `classifies a runway as paved only when every material is known and paved`(
    materials: [Runway.Material],
    hasUnrecognizedMaterials: Bool,
    isPaved: Bool?
  ) {
    let runway = makeRunway(
      materials: Set(materials),
      hasUnrecognizedMaterials: hasUnrecognizedMaterials
    )
    #expect(runway.isPaved == isPaved)
  }

  private func makeRunway(materials: Set<Runway.Material>, hasUnrecognizedMaterials: Bool) -> Runway
  {
    Runway(
      identification: "18/36",
      lengthFt: nil,
      widthFt: nil,
      lengthSource: nil,
      lengthSourceDateComponents: nil,
      materials: materials,
      hasUnrecognizedMaterials: hasUnrecognizedMaterials,
      condition: nil,
      treatment: nil,
      pavementClassification: nil,
      edgeLightsIntensity: nil,
      baseEnd: RunwayEnd(
        id: "18",
        heading: nil,
        instrumentLandingSystem: nil,
        rightTraffic: nil,
        marking: nil,
        markingCondition: nil,
        threshold: nil,
        thresholdCrossingHeightFtAGL: nil,
        visualGlidepathDeg: nil,
        displacedThreshold: nil,
        thresholdDisplacementFt: nil,
        touchdownZoneElevationFtMSL: nil,
        gradientPct: nil,
        TORAFt: nil,
        TODAFt: nil,
        ASDAFt: nil,
        LDAFt: nil,
        LAHSO: nil,
        visualGlideslopeIndicator: nil,
        RVRSensors: [],
        hasRVV: nil,
        approachLighting: nil,
        hasREIL: nil,
        hasCenterlineLighting: nil,
        hasEndTouchdownLighting: nil,
        controllingObject: nil,
        positionSource: nil,
        positionSourceDateComponents: nil,
        elevationSource: nil,
        elevationSourceDateComponents: nil,
        displacedThresholdPositionSource: nil,
        displacedThresholdPositionSourceDateComponents: nil,
        displacedThresholdElevationSource: nil,
        displacedThresholdElevationSourceDateComponents: nil,
        touchdownZoneElevationSource: nil,
        touchdownZoneElevationSourceDateComponents: nil
      ),
      reciprocalEnd: nil,
      singleWheelWeightBearingCapacityKlb: nil,
      dualWheelWeightBearingCapacityKlb: nil,
      tandemDualWheelWeightBearingCapacityKlb: nil,
      doubleTandemDualWheelWeightBearingCapacityKlb: nil
    )
  }
}
