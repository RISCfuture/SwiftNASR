import Foundation

private let offsetParser = OffsetParser()

extension FixedWidthAirportParser {
  private var runwayTransformer: FixedWidthTransformer {
    .init([
      .recordType,  //   0 record type
      .string(),  //   1 site number
      .string(nullable: .blank),  //   2 state post office code
      .string(),  //   3 identification

      .unsignedInteger(nullable: .blank),  //   4 length
      .unsignedInteger(nullable: .blank),  //   5 width
      .string(nullable: .blank),  //   6 surface type and condition
      .generic(
        { try SwiftNASR.raw($0, toEnum: Runway.Treatment.self) },
        nullable: .sentinel(["", "NONE"])
      ),  //   7 surface treament
      .string(nullable: .blank),  //   8 pavement classification
      .generic(
        { try SwiftNASR.raw($0, toEnum: Runway.EdgeLightIntensity.self) },
        nullable: .sentinel(["", "NONE"])
      ),  //   9 edge light intensity

      .string(),  //  10 base end: identifier
      .unsignedInteger(nullable: .blank),  //  11 base end: true heading
      .generic(
        { try SwiftNASR.raw($0, toEnum: RunwayEnd.InstrumentLandingSystem.self) },
        nullable: .blank
      ),  //  12 base end: ILS
      .boolean(nullable: .blank),  //  13 base end: right pattern
      .generic(
        { try SwiftNASR.raw($0, toEnum: RunwayEnd.Marking.self) },
        nullable: .sentinel(["", "NONE"])
      ),  //  14 base end: markings
      .generic(
        { try SwiftNASR.raw($0, toEnum: RunwayEnd.MarkingCondition.self) },
        nullable: .blank
      ),  //  15 base end: marking condition
      .DDMMSS(nullable: .blank),  //  16 base end: latitude
      .null,  //  17 base end: latitude
      .DDMMSS(nullable: .blank),  //  18 base end: longitude
      .null,  //  19 base end: longitude
      .float(nullable: .blank),  //  20 base end: elevation
      .unsignedInteger(nullable: .blank),  //  21 base end: TCH
      .float(nullable: .blank),  //  22 base end: GP angle
      .DDMMSS(nullable: .blank),  //  23 base end: displaced threshold latitude
      .null,  //  24 base end: displaced threshold latitude
      .DDMMSS(nullable: .blank),  //  25 base end: displaced threshold longitude
      .null,  //  26 base end: displaced threshold longitude
      .float(nullable: .blank),  //  27 base end: displaced threshold elevation
      .unsignedInteger(nullable: .sentinel(["", "NONE"])),  //  28 base end: displaced threshold distance
      .float(nullable: .blank),  //  29 base end: TDZE

      .string(nullable: .sentinel(["", "NONE", "N"])),  //  30 base end: VGSI
      .fixedWidthArray(
        width: 1,
        convert: { try SwiftNASR.raw($0, toEnum: RunwayEnd.RVRSensor.self) },
        nullable: .compact,
        emptyPlaceholders: ["N"]
      ),  //  31 base end: RVR
      .boolean(nullable: .blank),  //  32 base end: has RVV
      .generic(
        { try SwiftNASR.raw($0, toEnum: RunwayEnd.ApproachLighting.self) },
        nullable: .sentinel(["", "NONE"])
      ),  //  33 base end: approach lighting
      .boolean(nullable: .blank),  //  34 base end: REILs
      .boolean(nullable: .blank),  //  35 base end: CL
      .boolean(nullable: .blank),  //  36 base end: TDZL

      .generic(
        { try SwiftNASR.raw($0, toEnum: RunwayEnd.ControllingObject.Category.self) },
        nullable: .blank
      ),  //  37 base end: controlling object
      .fixedWidthArray(
        width: 1,
        convert: { try SwiftNASR.raw($0, toEnum: RunwayEnd.ControllingObject.Marking.self) },
        nullable: .compact,
        emptyPlaceholders: ["", "NONE", "NL"]
      ),  //  38 base end: controlling object marking
      .string(nullable: .blank),  //  39 base end: controlling runway category
      .unsignedInteger(nullable: .blank),  //  40 base end: controlling object slope
      .unsignedInteger(nullable: .blank),  //  41 base end: controlling object height
      .unsignedInteger(nullable: .blank),  //  42 base end: controlling object distance
      .generic({ try offsetParser.parse($0) }, nullable: .blank),  //  43 base end: controlling object offset

      .string(nullable: .blank),  //  44 reciprocal end: identifier
      .unsignedInteger(nullable: .blank),  //  45 reciprocal end: true heading
      .generic(
        { try SwiftNASR.raw($0, toEnum: RunwayEnd.InstrumentLandingSystem.self) },
        nullable: .blank
      ),  //  46 reciprocal end: ILS
      .boolean(nullable: .blank),  //  47 reciprocal end: right pattern
      .generic(
        { try SwiftNASR.raw($0, toEnum: RunwayEnd.Marking.self) },
        nullable: .sentinel(["", "NONE"])
      ),  //  48 reciprocal end: markings
      .generic(
        { try SwiftNASR.raw($0, toEnum: RunwayEnd.MarkingCondition.self) },
        nullable: .blank
      ),  //  49 reciprocal end: marking condition
      .DDMMSS(nullable: .blank),  //  50 reciprocal end: latitude
      .null,  //  51 reciprocal end: latitude
      .DDMMSS(nullable: .blank),  //  52 reciprocal end: longitude
      .null,  //  53 reciprocal end: longitude
      .float(nullable: .blank),  //  54 reciprocal end: elevation
      .unsignedInteger(nullable: .blank),  //  55 reciprocal end: TCH
      .float(nullable: .blank),  //  56 reciprocal end: GP angle
      .DDMMSS(nullable: .blank),  //  57 reciprocal end: displaced threshold latitude
      .null,  //  58 reciprocal end: displaced threshold latitude
      .DDMMSS(nullable: .blank),  //  59 reciprocal end: displaced threshold longitude
      .null,  //  60 reciprocal end: displaced threshold longitude
      .float(nullable: .blank),  //  61 reciprocal end: displaced threshold elevation
      .unsignedInteger(nullable: .sentinel(["", "NONE"])),  //  62 reciprocal end: displaced threshold distance
      .float(nullable: .blank),  //  63 reciprocal end: TDZE

      .string(nullable: .sentinel(["", "NONE", "N"])),  //  64 reciprocal end: VGSI
      .fixedWidthArray(
        width: 1,
        convert: { try SwiftNASR.raw($0, toEnum: RunwayEnd.RVRSensor.self) },
        nullable: .compact,
        emptyPlaceholders: ["N"]
      ),  //  65 reciprocal end: RVR
      .boolean(nullable: .blank),  //  66 reciprocal end: has RVV
      .generic(
        { try SwiftNASR.raw($0, toEnum: RunwayEnd.ApproachLighting.self) },
        nullable: .sentinel(["", "NONE"])
      ),  //  67 reciprocal end: approach lighting
      .boolean(nullable: .blank),  //  68 reciprocal end: REILs
      .boolean(nullable: .blank),  //  69 reciprocal end: CL
      .boolean(nullable: .blank),  //  70 reciprocal end: TDZL

      .generic(
        { try SwiftNASR.raw($0, toEnum: RunwayEnd.ControllingObject.Category.self) },
        nullable: .blank
      ),  //  71 reciprocal end: controlling object
      .fixedWidthArray(
        width: 1,
        convert: { try SwiftNASR.raw($0, toEnum: RunwayEnd.ControllingObject.Marking.self) },
        nullable: .compact,
        emptyPlaceholders: ["", "NONE", "NL"]
      ),  //  72 reciprocal end: controlling object marking
      .string(nullable: .blank),  //  73 reciprocal end: controlling runway category
      .unsignedInteger(nullable: .blank),  //  74 reciprocal end: controlling object slope
      .unsignedInteger(nullable: .blank),  //  75 reciprocal end: controlling object height
      .unsignedInteger(nullable: .blank),  //  76 reciprocal end: controlling object distance
      .generic({ try offsetParser.parse($0) }, nullable: .blank),  //  77 reciprocal end: controlling object offset

      .string(nullable: .blank),  //  78 runway length source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  //  79 runway length source date
      .float(nullable: .blank),  //  80 single wheel weight bearing capacity
      .float(nullable: .blank),  //  81 dual wheel weight bearing capacity
      .float(nullable: .blank),  //  82 tandem weight bearing capacity
      .float(nullable: .blank),  //  83 dual tandem weight bearing capacity

      .float(nullable: .blank),  //  84 base end: gradient
      .string(nullable: .blank),  //  85 base end: gradient up/down
      .string(nullable: .blank),  //  86 base end: position source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  //  87 base end: position source date
      .string(nullable: .blank),  //  88 base end: elevation source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  //  89 base end: elevation source date
      .string(nullable: .blank),  //  90 base end: displaced threshold position source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  //  91 base end: displaced threshold position source date
      .string(nullable: .blank),  //  92 base end: displaced threshold elevation source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  //  93 base end: displaced threshold elevation source date
      .string(nullable: .blank),  //  94 base end: TDZE source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  //  95 base end: TDZE source date
      .unsignedInteger(nullable: .blank),  //  96 base end: TORA
      .unsignedInteger(nullable: .blank),  //  97 base end: TODA
      .unsignedInteger(nullable: .blank),  //  98 base end: ASDA
      .unsignedInteger(nullable: .blank),  //  99 base end: LDA
      .unsignedInteger(nullable: .blank),  // 100 base end: LAHSO distance
      .string(nullable: .blank),  // 101 base end: LAHSO intersection ID
      .string(nullable: .blank),  // 102 base end: LAHSO intersection description
      .DDMMSS(nullable: .blank),  // 103 base end: LAHSO latitude
      .null,  // 104 base end: LAHSO latitude
      .DDMMSS(nullable: .blank),  // 105 base end: LAHSO longitude
      .null,  // 106 base end: LAHSO longitude
      .string(nullable: .blank),  // 107 base end: LAHSO position source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  // 108 base end: LAHSO position source date

      .float(nullable: .blank),  // 109 reciprocal end: gradient
      .string(nullable: .blank),  // 110 reciprocal end: gradient up/down
      .string(nullable: .blank),  // 111 reciprocal end: position source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  // 112 reciprocal end: position source date
      .string(nullable: .blank),  // 113 reciprocal end: elevation source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  // 114 reciprocal end: elevation source date
      .string(nullable: .blank),  // 115 reciprocal end: displaced threshold position source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  // 116 reciprocal end: displaced threshold position source date
      .string(nullable: .blank),  // 117 reciprocal end: displaced threshold elevation source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  // 118 reciprocal end: displaced threshold elevation source date
      .string(nullable: .blank),  // 119 reciprocal end: TDZE source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  // 120 reciprocal end: TDZE source date
      .unsignedInteger(nullable: .blank),  // 121 reciprocal end: TORA
      .unsignedInteger(nullable: .blank),  // 122 reciprocal end: TODA
      .unsignedInteger(nullable: .blank),  // 123 reciprocal end: ASDA
      .unsignedInteger(nullable: .blank),  // 124 reciprocal end: LDA
      .unsignedInteger(nullable: .blank),  // 125 reciprocal end: LAHSO distance
      .string(nullable: .blank),  // 126 reciprocal end: LAHSO intersection ID
      .string(nullable: .blank),  // 127 reciprocal end: LAHSO intersection description
      .DDMMSS(nullable: .blank),  // 128 reciprocal end: LAHSO latitude
      .null,  // 129 reciprocal end: LAHSO latitude
      .DDMMSS(nullable: .blank),  // 130 reciprocal end: LAHSO longitude
      .null,  // 131 reciprocal end: LAHSO longitude
      .string(nullable: .blank),  // 132 reciprocal end: LAHSO position source
      .dateComponents(
        format: .monthDayYearSlash,
        nullable: .blank
      ),  // 133 base end: LAHSO position source date

      .null  // 134 filler
    ])
  }

  func parseRunwayRecord(_ values: [String]) throws {
    let airportIndex: String = values[1].trimmingCharacters(in: .whitespaces)
    guard let airport = airports[airportIndex] else { return }

    let transformedValues = try runwayTransformer.applyTo(values)

    let (materials, condition): (Set<Runway.Material>, Runway.Condition?)
    if let condStr = transformedValues[6] as? String {
      do {
        (materials, condition) = try parseRunwaySurface(condStr)
      } catch {
        throw FixedWidthParserError.invalidValue(condStr, at: 6)
      }
    } else {
      (materials, condition) = (.init(), nil)
    }

    let pavementClassification: Runway.PavementClassification?
    if let classStr = transformedValues[8] as? String {
      do {
        pavementClassification = try parsePavementClassification(classStr)
      } catch {
        throw FixedWidthParserError.invalidValue(classStr, at: 8)
      }
    } else {
      pavementClassification = nil
    }

    let base = try parseRunwayEnd(transformedValues, offset1: 10, offset2: 84, airport: airport)
    let reciprocal: RunwayEnd?
    if transformedValues[44] != nil {
      reciprocal = try parseRunwayEnd(
        transformedValues,
        offset1: 44,
        offset2: 109,
        airport: airport
      )
    } else {
      reciprocal = nil
    }

    let singleWheelWeightBearingCapacityKlb = transformedValues[80].map { capacity in
      UInt((capacity as! Float) * 1000)
    }
    let dualWheelWeightBearingCapacityKlb = transformedValues[81].map { capacity in
      UInt((capacity as! Float) * 1000)
    }
    let tandemDualWheelWeightBearingCapacityKlb = transformedValues[82].map { capacity in
      UInt((capacity as! Float) * 1000)
    }
    let doubleTandemDualWheelWeightBearingCapacityKlb = transformedValues[83].map { capacity in
      UInt((capacity as! Float) * 1000)
    }

    let runway = Runway(
      identification: transformedValues[3] as! String,
      lengthFt: transformedValues[4] as! UInt?,
      widthFt: transformedValues[5] as! UInt?,
      lengthSource: transformedValues[78] as! String?,
      lengthSourceDateComponents: transformedValues[79] as! DateComponents?,
      materials: materials,
      condition: condition,
      treatment: transformedValues[7] as! Runway.Treatment?,
      pavementClassification: pavementClassification,
      edgeLightsIntensity: transformedValues[9] as! Runway.EdgeLightIntensity?,
      baseEnd: base,
      reciprocalEnd: reciprocal,
      singleWheelWeightBearingCapacityKlb: singleWheelWeightBearingCapacityKlb,
      dualWheelWeightBearingCapacityKlb: dualWheelWeightBearingCapacityKlb,
      tandemDualWheelWeightBearingCapacityKlb: tandemDualWheelWeightBearingCapacityKlb,
      doubleTandemDualWheelWeightBearingCapacityKlb: doubleTandemDualWheelWeightBearingCapacityKlb
    )

    airports[airportIndex]!.runways.append(runway)
  }

  private func parseRunwaySurface(_ value: String) throws -> (
    Set<Runway.Material>, Runway.Condition?
  ) {
    var materials = Set<Runway.Material>()
    var condition: Runway.Condition?

    for identifier in value.split(separator: CharacterSet(charactersIn: "-/")) {
      if let material = Runway.Material.for(String(identifier)) {
        materials.insert(material)
      } else {
        condition = Runway.Condition.for(String(identifier))
        guard condition != nil else { throw Error.invalidRunwaySurface(value) }  // something we don't know
      }
    }

    return (materials, condition)
  }

  private func parsePavementClassification(_ value: String) throws -> Runway.PavementClassification
  {
    let components = value.split(separator: "/")
    let numberStr = String(components[0]).trimmingCharacters(in: .whitespaces)
    guard let number = UInt(numberStr) else { throw Error.invalidPavementClassification(value) }
    let type = try SwiftNASR.raw(
      String(components[1]),
      toEnum: Runway.PavementClassification.Classification.self
    )
    let strength = try SwiftNASR.raw(
      String(components[2]),
      toEnum: Runway.PavementClassification.SubgradeStrengthCategory.self
    )
    let tirePressure = try SwiftNASR.raw(
      String(components[3]),
      toEnum: Runway.PavementClassification.TirePressureLimit.self
    )
    let determination = try SwiftNASR.raw(
      String(components[4]),
      toEnum: Runway.PavementClassification.DeterminationMethod.self
    )

    return Runway.PavementClassification(
      number: number,
      type: type,
      subgradeStrengthCategory: strength,
      tirePressureLimit: tirePressure,
      determinationMethod: determination
    )
  }
}
