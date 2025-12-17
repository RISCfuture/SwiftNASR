import Foundation

enum NavaidRecordIdentifier: String {
  case basicInfo = "NAV1"
  case remark = "NAV2"
  case fixes = "NAV3"
  case holdingPatterns = "NAV4"
  case fanMarkers = "NAV5"
  case VORCheckpoint = "NAV6"
}

struct NavaidKey: Hashable {
  let ID: String
  let type: Navaid.FacilityType
  let city: String

  init(navaid: Navaid) {
    ID = navaid.id
    type = navaid.type
    city = navaid.city
  }

  /// Initialize from transformed values for NAV2-NAV6 records.
  /// These records don't include city, so we use an empty string.
  /// This means lookups will only work correctly if there's only one navaid
  /// with the given (ID, type) combination.
  init(values: [Any?]) {
    ID = values[1] as! String
    type = values[2] as! Navaid.FacilityType
    city = ""  // NAV2-NAV6 records don't include city
  }
}

class FixedWidthNavaidParser: FixedWidthParser {
  typealias RecordIdentifier = NavaidRecordIdentifier

  static let type: RecordType = .navaids
  static let layoutFormatOrder: [NavaidRecordIdentifier] = [
    .basicInfo, .remark, .fixes, .holdingPatterns, .fanMarkers, .VORCheckpoint
  ]

  var recordTypeRange: Range<UInt> { 0..<4 }
  var formats = [NASRTable]()
  var navaids = [NavaidKey: Navaid]()

  private let basicTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type
    .string(),  //  1 identifier
    .generic { try raw($0, toEnum: Navaid.FacilityType.self) },  //  2 facility type
    .null,  //  3 identifier

    .null,  //  4 effective date
    .string(),  //  5 name
    .string(),  //  6 city
    .string(nullable: .blank),  //  7 state name
    .null,  //  8 state PO code
    .string(),  //  9 FAA region
    .string(nullable: .blank),  // 10 country
    .null,  // 11 country PO code
    .string(nullable: .blank),  // 12 owner name
    .string(nullable: .blank),  // 13 operator name
    .boolean(),  // 14 common system
    .boolean(),  // 15 public use
    .generic({ try parseClassDesignator($0) }, nullable: .blank),  // 16 navaid class
    .string(nullable: .blank),  // 17 hours of operation
    .string(nullable: .blank),  // 18 high alt ARTCC code
    .null,  // 19 high alt ARTCC name
    .string(nullable: .blank),  // 20 low alt ARTCC code
    .null,  // 21 low alt ARTCC name

    .DDMMSS(),  // 22 latitude
    .null,  // 23 latitude (sec)
    .DDMMSS(),  // 24 longitude
    .null,  // 25 longitude (sec)
    .generic({ try parseSurveyAccuracy($0) }, nullable: .blank),  // 26 survey accuracy
    .DDMMSS(nullable: .blank),  // 27 TACAN lat
    .null,  // 28 TACAN lat (sec)
    .DDMMSS(nullable: .blank),  // 29 TACAN lon
    .null,  // 30 TACAN lon (sec)
    .float(nullable: .blank),  // 31 elevation
    .generic({ try parseMagVar($0, fieldIndex: 32) }, nullable: .blank),  // 32 magvar
    .dateComponents(format: .yearOnly, nullable: .blank),  // 33 magvar epoch

    .boolean(nullable: .blank),  // 34 simul voice output
    .unsignedInteger(nullable: .blank),  // 35 power output
    .boolean(nullable: .blank),  // 36 auto voice ident
    .generic({ try raw($0, toEnum: Navaid.MonitoringCategory.self) }, nullable: .blank),  // 37 monitoring category
    .string(nullable: .sentinel(["", "NONE"])),  // 38 radio voice call
    .generic({ try parseTACAN($0, fieldIndex: 39) }, nullable: .blank),  // 39 TACAN channel
    .frequency(nullable: .blank),  // 40 freq
    .string(nullable: .blank),  // 41 fan marker ident
    .generic({ try raw($0, toEnum: Navaid.FanMarkerType.self) }, nullable: .blank),  // 42 fan marker type
    .unsignedInteger(nullable: .blank),  // 43 fan marker major axis
    .generic({ try parseServiceVolume($0) }, nullable: .blank),  // 44 VOR service volume
    .generic({ try parseServiceVolume($0) }, nullable: .blank),  // 45 DME service volume
    .boolean(nullable: .blank),  // 46 lo facility in hi structure
    .boolean(nullable: .blank),  // 47 Z marker
    .string(nullable: .blank),  // 48 TWEB hours
    .string(nullable: .blank),  // 49 TWEB phone
    .string(nullable: .blank),  // 50 FSS ident
    .null,  // 51 FSS name
    .null,  // 52 FSS hours
    .string(nullable: .blank),  // 53 NOTAM accountability code

    .generic({ try parseLFRLegs($0, fieldIndex: 54) }, nullable: .blank),  // 54 quadrant identification and range leg bearing

    .generic { try raw($0, toEnum: OperationalStatus.self) },  // 55 status

    .boolean(),  // 56 pitch flag
    .boolean(),  // 57 catch flag
    .boolean(),  // 58 SUA flag
    .boolean(nullable: .blank),  // 59 restriction flag
    .boolean(nullable: .blank),  // 60 hiwas flag
    .boolean(nullable: .blank)  // 61 tweb restriction flag
  ])

  private let remarkTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 id
    .generic { try raw($0, toEnum: Navaid.FacilityType.self) },  // 2 facility type

    .string(),  // 3 remark
    .null  // 4 filler
  ])

  private let fixTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 id
    .generic { try raw($0, toEnum: Navaid.FacilityType.self) },  // 2 facility type

    .generic { $0.split(separator: "*").first },  // 3 first fix
    .fixedWidthArray(width: 36, convert: { $0.split(separator: "*").first }, nullable: .blank),  // 4 other fixes
    .null  // 5 blank
  ])

  private let holdingPatternTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 id
    .generic { try raw($0, toEnum: Navaid.FacilityType.self) },  // 2 facility type

    .string(),  // 3 first pattern name
    .unsignedInteger(),  // 4 first pattern number
    .fixedWidthArray(
      width: 83,
      convert: { try parseHoldingPattern($0, fieldIndex: 5) },
      nullable: .blank
    ),  // 5 other patterns
    .null  // 6 blank
  ])

  private let fanMarkerTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 id
    .generic { try raw($0, toEnum: Navaid.FacilityType.self) },  // 2 facility type

    .string(),  // 3 first fan marker
    .fixedWidthArray(width: 30, nullable: .blank),  // 4 other fan markers
    .null  // 5 blank
  ])

  private let checkpointTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type
    .string(),  //  1 id
    .generic { try raw($0, toEnum: Navaid.FacilityType.self) },  //  2 facility type

    .generic { try raw($0, toEnum: VORCheckpoint.CheckpointType.self) },  //  3 A/G code
    .unsignedInteger(),  //  4 bearing
    .integer(nullable: .blank),  //  5 altitude
    .string(nullable: .blank),  //  6 airport code
    .string(),  //  7 state code
    .string(nullable: .blank),  //  8 air desc
    .string(nullable: .blank),  //  9 gnd desc
    .null  // 10 blank
  ])

  func parseValues(_ values: [String], for identifier: NavaidRecordIdentifier) throws {
    switch identifier {
      case .basicInfo: try parseBasicRecord(values)
      case .remark: try parseRemark(values)
      case .fixes: try parseFixes(values)
      case .holdingPatterns: try parseHoldingPatterns(values)
      case .fanMarkers: try parseFanMarkers(values)
      case .VORCheckpoint: try parseCheckpoint(values)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(navaids: Array(navaids.values))
  }

  private func parseBasicRecord(_ values: [String]) throws {
    let transformedValues = try basicTransformer.applyTo(values)

    let position = Location(
      latitude: transformedValues[22] as! Float,
      longitude: transformedValues[24] as! Float,
      elevation: transformedValues[31] as! Float?
    )
    let TACANPosition = zipOptionals(transformedValues[27], transformedValues[29]).map { lat, lon in
      Location(latitude: lat as! Float, longitude: lon as! Float, elevation: nil)
    }

    let magneticVariation = transformedValues[32] as! Int?

    // Convert fan marker bearing to Bearing<UInt>
    let fanMarkerMajorBearing = (transformedValues[43] as! UInt?).map { value in
      Bearing(value, reference: .magnetic, magneticVariation: magneticVariation ?? 0)
    }

    // Convert LFR leg bearings to Bearing<UInt>
    let rawLFRLegs = transformedValues[54] as! [(LFRLeg.Quadrant, UInt)]?
    let LFRLegs = rawLFRLegs?.map { quadrant, bearing in
      LFRLeg(
        quadrant: quadrant,
        bearing: Bearing(bearing, reference: .magnetic, magneticVariation: magneticVariation ?? 0)
      )
    }

    let navaid = Navaid(
      id: transformedValues[1] as! String,
      name: transformedValues[5] as! String,
      type: transformedValues[2] as! Navaid.FacilityType,
      city: transformedValues[6] as! String,
      stateName: transformedValues[7] as! String?,
      FAARegion: transformedValues[9] as! String,
      country: transformedValues[10] as! String?,
      ownerName: transformedValues[12] as! String?,
      operatorName: transformedValues[13] as! String?,
      commonSystemUsage: transformedValues[14] as! Bool,
      publicUse: transformedValues[15] as! Bool,
      navaidClass: transformedValues[16] as! Navaid.NavaidClass?,
      hoursOfOperation: transformedValues[17] as! String?,
      highAltitudeARTCCCode: transformedValues[18] as! String?,
      lowAltitudeARTCCCode: transformedValues[20] as! String?,
      position: position,
      TACANPosition: TACANPosition,
      surveyAccuracy: transformedValues[26] as! Navaid.SurveyAccuracy?,
      magneticVariation: magneticVariation,
      magneticVariationEpoch: transformedValues[33] as! DateComponents?,
      simultaneousVoice: transformedValues[34] as! Bool?,
      powerOutput: transformedValues[35] as! UInt?,
      automaticVoiceId: transformedValues[36] as! Bool?,
      monitoringCategory: transformedValues[37] as! Navaid.MonitoringCategory?,
      radioVoiceCall: transformedValues[38] as! String?,
      tacanChannel: transformedValues[39] as! Navaid.TACANChannel?,
      frequency: transformedValues[40] as! UInt?,
      beaconIdentifier: transformedValues[41] as! String?,
      fanMarkerType: transformedValues[42] as! Navaid.FanMarkerType?,
      fanMarkerMajorBearing: fanMarkerMajorBearing,
      VORServiceVolume: transformedValues[44] as! Navaid.ServiceVolume?,
      DMEServiceVolume: transformedValues[45] as! Navaid.ServiceVolume?,
      lowAltitudeInHighStructure: transformedValues[46] as! Bool?,
      ZMarkerAvailable: transformedValues[47] as! Bool?,
      TWEBHours: transformedValues[48] as! String?,
      TWEBPhone: transformedValues[49] as! String?,
      controllingFSSCode: transformedValues[50] as! String?,
      NOTAMAccountabilityCode: transformedValues[53] as! String?,
      LFRLegs: LFRLegs,
      status: transformedValues[55] as! OperationalStatus,
      isPitchPoint: transformedValues[56] as? Bool,
      isCatchPoint: transformedValues[57] as? Bool,
      isAssociatedWithSUA: transformedValues[58] as? Bool,
      hasRestriction: transformedValues[59] as! Bool?,
      broadcastsHIWAS: transformedValues[60] as! Bool?,
      hasTWEBRestriction: transformedValues[61] as! Bool?
    )
    navaids[NavaidKey(navaid: navaid)] = navaid
  }

  private func parseRemark(_ values: [String]) throws {
    let transformedValues = try remarkTransformer.applyTo(values)
    try updateNavaid(transformedValues) { navaid in
      navaid.remarks.append(transformedValues[3] as! String)
    }
  }

  private func parseFixes(_ values: [String]) throws {
    let transformedValues = try fixTransformer.applyTo(values)
    try updateNavaid(transformedValues) { navaid in
      navaid.associatedFixNames.insert(String(transformedValues[3] as! Substring))
      if let otherFixes = transformedValues[4] as? [Substring] {
        for fix in otherFixes {
          navaid.associatedFixNames.insert(String(fix))
        }
      }
    }
  }

  private func parseHoldingPatterns(_ values: [String]) throws {
    let transformedValues = try holdingPatternTransformer.applyTo(values)
    try updateNavaid(transformedValues) { navaid in
      let pattern = HoldingPatternId(
        name: transformedValues[3] as! String,
        number: transformedValues[4] as! UInt
      )
      navaid.associatedHoldingPatterns.insert(pattern)

      if let otherPatterns = transformedValues[5] as? [HoldingPatternId] {
        for pattern in otherPatterns {
          navaid.associatedHoldingPatterns.insert(pattern)
        }
      }
    }
  }

  private func parseFanMarkers(_ values: [String]) throws {
    let transformedValues = try fanMarkerTransformer.applyTo(values)
    try updateNavaid(transformedValues) { navaid in
      navaid.fanMarkers.insert(transformedValues[3] as! String)
      if let otherMarkers = transformedValues[4] as? [String] {
        for fanMarker in otherMarkers {
          navaid.fanMarkers.insert(fanMarker)
        }
      }
    }
  }

  private func parseCheckpoint(_ values: [String]) throws {
    let transformedValues = try checkpointTransformer.applyTo(values)
    try updateNavaid(transformedValues) { navaid in
      let bearing = Bearing(
        transformedValues[4] as! UInt,
        reference: .magnetic,
        magneticVariation: navaid.magneticVariation ?? 0
      )
      let checkpoint = VORCheckpoint(
        type: transformedValues[3] as! VORCheckpoint.CheckpointType,
        bearing: bearing,
        altitude: transformedValues[5] as! Int?,
        airportId: transformedValues[6] as! String?,
        stateCode: transformedValues[7] as! String,
        airDescription: transformedValues[8] as! String?,
        groundDescription: transformedValues[9] as! String?
      )
      navaid.checkpoints.append(checkpoint)
    }
  }

  private func updateNavaid(_ transformedValues: [Any?], process: (inout Navaid) throws -> Void)
    throws
  {
    let navaidID = transformedValues[1] as! String
    let navaidType = transformedValues[2] as! Navaid.FacilityType

    // Find matching navaid by ID and type (NAV2-NAV6 records don't include city)
    // If there are multiple navaids with same (ID, type), we take the first match.
    // This is a limitation of the TXT format.
    guard
      let matchingKey = navaids.keys.first(where: { $0.ID == navaidID && $0.type == navaidType })
    else {
      throw Error.unknownNavaid(navaidID)
    }

    guard var navaid = navaids[matchingKey] else {
      throw Error.unknownNavaid(navaidID)
    }

    try process(&navaid)

    navaids[matchingKey] = navaid
  }
}

private let classDesignatorDelimiters = CharacterSet(charactersIn: "-/")

private func parseLFRLegs(_ string: String, fieldIndex: Int) throws -> [(LFRLeg.Quadrant, UInt)] {
  let scanner = Scanner(string: string)
  var legs = [(LFRLeg.Quadrant, UInt)]()

  while !scanner.isAtEnd {
    guard let bearing = scanner.scanInt(),
      let quadrantChar = scanner.scanCharacter()
    else {
      throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
    }
    guard let quadrant = LFRLeg.Quadrant.for(String(quadrantChar)) else {
      throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
    }
    legs.append((quadrant, UInt(bearing)))
  }

  return legs
}
