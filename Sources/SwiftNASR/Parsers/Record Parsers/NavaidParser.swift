import Foundation

/// Converts a navaid frequency string to Hz based on the navaid type.
///
/// NDB-type navaids (NDB, NDB/DME, Marine NDB, Marine NDB/DME, UHF/NDB) store
/// frequencies in kHz (e.g., "365" = 365 kHz = 365,000 Hz).
///
/// VOR-type navaids (VOR, VOR/DME, VORTAC, TACAN, VOT, DME, etc.) store
/// frequencies in MHz with decimals (e.g., "113.00" = 113 MHz = 113,000,000 Hz).
///
/// - Parameters:
///   - frequencyString: The raw frequency string from the data file.
///   - navaidType: The type of navaid to determine the input unit.
/// - Returns: The frequency in Hz, or nil if the string is empty or unparseable.
func parseNavaidFrequencyToHz(_ frequencyString: String?, navaidType: Navaid.FacilityType) -> UInt?
{
  guard let frequencyString, !frequencyString.isEmpty else { return nil }

  // NDB-type navaids use kHz (whole numbers like "365")
  // All others use MHz (decimals like "113.00" or "117.8")
  let usesKHz: Bool
  switch navaidType {
    case .NDB, .NDB_DME, .marineNDB, .marineNDB_DME, .UHF_NDB, .LFR:
      usesKHz = true
    default:
      usesKHz = false
  }

  if usesKHz {
    // Input is in kHz (e.g., "365"), output in Hz
    guard let kHz = UInt(frequencyString) else { return nil }
    return kHz * 1000
  }
  // Input is in MHz (e.g., "113.00"), output in Hz
  guard let MHz = Double(frequencyString) else { return nil }
  return UInt(MHz * 1_000_000)
}

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
  init(values: FixedWidthTransformedRow) throws {
    ID = try values[1]
    type = try values[2]
    city = ""  // NAV2-NAV6 records don't include city
  }

  init(ID: String, type: Navaid.FacilityType, city: String) {
    self.ID = ID
    self.type = type
    self.city = city
  }
}

actor FixedWidthNavaidParser: FixedWidthParser {
  typealias RecordIdentifier = NavaidRecordIdentifier

  static let type: RecordType = .navaids
  static let layoutFormatOrder: [NavaidRecordIdentifier] = [
    .basicInfo, .remark, .fixes, .holdingPatterns, .fanMarkers, .VORCheckpoint
  ]

  var recordTypeRange: Range<UInt> { 0..<4 }
  var formats = [NASRTable]()
  var navaids = [NavaidKey: Navaid]()

  private let basicTransformer = ByteTransformer([
    .recordType,  //  0 record type
    .string(),  //  1 identifier
    .recordEnum(Navaid.FacilityType.self),  //  2 facility type
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
    .recordEnum(Navaid.MonitoringCategory.self, nullable: .blank),  // 37 monitoring category
    .string(nullable: .sentinel(["", "NONE"])),  // 38 radio voice call
    .generic({ try parseTACAN($0, fieldIndex: 39) }, nullable: .blank),  // 39 TACAN channel
    .string(nullable: .blank),  // 40 freq (raw string - converted to Hz in parseBasicRecord based on navaid type)
    .string(nullable: .blank),  // 41 fan marker ident
    .recordEnum(Navaid.FanMarkerType.self, nullable: .blank),  // 42 fan marker type
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

    .recordEnum(OperationalStatus.self),  // 55 status

    .boolean(),  // 56 pitch flag
    .boolean(),  // 57 catch flag
    .boolean(),  // 58 SUA flag
    .boolean(nullable: .blank),  // 59 restriction flag
    .boolean(nullable: .blank),  // 60 hiwas flag
    .boolean(nullable: .blank)  // 61 tweb restriction flag
  ])

  private let remarkTransformer = ByteTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 id
    .recordEnum(Navaid.FacilityType.self),  // 2 facility type

    .string(),  // 3 remark
    .null  // 4 filler
  ])

  private let fixTransformer = ByteTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 id
    .recordEnum(Navaid.FacilityType.self),  // 2 facility type

    .generic { $0.split(separator: "*").first },  // 3 first fix
    .fixedWidthArray(width: 36, convert: { $0.split(separator: "*").first }, nullable: .blank),  // 4 other fixes
    .null  // 5 blank
  ])

  private let holdingPatternTransformer = ByteTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 id
    .recordEnum(Navaid.FacilityType.self),  // 2 facility type

    .string(),  // 3 first pattern name
    .unsignedInteger(),  // 4 first pattern number
    .fixedWidthArray(
      width: 83,
      convert: { try parseHoldingPattern($0, fieldIndex: 5) },
      nullable: .blank
    ),  // 5 other patterns
    .null  // 6 blank
  ])

  private let fanMarkerTransformer = ByteTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 id
    .recordEnum(Navaid.FacilityType.self),  // 2 facility type

    .string(),  // 3 first fan marker
    .fixedWidthArray(width: 30, nullable: .blank),  // 4 other fan markers
    .null  // 5 blank
  ])

  private let checkpointTransformer = ByteTransformer([
    .recordType,  //  0 record type
    .string(),  //  1 id
    .recordEnum(Navaid.FacilityType.self),  //  2 facility type

    .recordEnum(VORCheckpoint.CheckpointType.self),  //  3 A/G code
    .unsignedInteger(),  //  4 bearing
    .integer(nullable: .blank),  //  5 altitude
    .string(nullable: .blank),  //  6 airport code
    .string(),  //  7 state code
    .string(nullable: .blank),  //  8 air desc
    .string(nullable: .blank),  //  9 gnd desc
    .null  // 10 blank
  ])

  func parseValues(_ values: [ArraySlice<UInt8>], for identifier: NavaidRecordIdentifier) throws {
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

  private func parseBasicRecord(_ values: [ArraySlice<UInt8>]) throws {
    let t = try basicTransformer.applyTo(values),
      lat: Float = try t[22],
      lon: Float = try t[24],
      elev: Float? = try t[optional: 31],
      position = Location(latitudeArcsec: lat, longitudeArcsec: lon, elevationFtMSL: elev),
      TACANLat: Float? = try t[optional: 27],
      TACANLon: Float? = try t[optional: 29],
      TACANPosition = zipOptionals(TACANLat, TACANLon).map { lat, lon in
        Location(latitudeArcsec: lat, longitudeArcsec: lon, elevationFtMSL: nil)
      },
      magneticVariationDeg: Int? = try t[optional: 32],
      // Convert fan marker bearing to Bearing<UInt>
      fanMarkerMajorBearingValue: UInt? = try t[optional: 43],
      fanMarkerMajorBearing = fanMarkerMajorBearingValue.map { value in
        Bearing(value, reference: .magnetic, magneticVariationDeg: magneticVariationDeg ?? 0)
      },
      // Convert LFR leg bearings to Bearing<UInt>
      rawLFRLegs: [(LFRLeg.Quadrant, UInt)]? = try t[optional: 54],
      navaidType: Navaid.FacilityType = try t[2],
      rawFreq: String? = try t[optional: 40]

    // Convert frequency to Hz based on navaid type
    // NDB/Marine NDB/UHF NDB use kHz, all others use MHz
    let frequencyHz = parseNavaidFrequencyToHz(rawFreq, navaidType: navaidType)

    let LFRLegs = rawLFRLegs?.map { quadrant, bearing in
      LFRLeg(
        quadrant: quadrant,
        bearing: Bearing(
          bearing,
          reference: .magnetic,
          magneticVariationDeg: magneticVariationDeg ?? 0
        )
      )
    }

    let navaid = Navaid(
      id: try t[1],
      name: try t[5],
      type: try t[2],
      city: try t[6],
      stateName: try t[optional: 7],
      FAARegion: try t[9],
      country: try t[optional: 10],
      ownerName: try t[optional: 12],
      operatorName: try t[optional: 13],
      commonSystemUsage: try t[14],
      publicUse: try t[15],
      navaidClass: try t[optional: 16],
      hoursOfOperation: try t[optional: 17],
      highAltitudeARTCCCode: try t[optional: 18],
      lowAltitudeARTCCCode: try t[optional: 20],
      position: position,
      TACANPosition: TACANPosition,
      surveyAccuracy: try t[optional: 26],
      magneticVariationDeg: magneticVariationDeg,
      magneticVariationEpochComponents: try t[optional: 33],
      simultaneousVoice: try t[optional: 34],
      powerOutputW: try t[optional: 35],
      automaticVoiceId: try t[optional: 36],
      monitoringCategory: try t[optional: 37],
      radioVoiceCall: try t[optional: 38],
      tacanChannel: try t[optional: 39],
      frequencyHz: frequencyHz,
      beaconIdentifier: try t[optional: 41],
      fanMarkerType: try t[optional: 42],
      fanMarkerMajorBearing: fanMarkerMajorBearing,
      VORServiceVolume: try t[optional: 44],
      DMEServiceVolume: try t[optional: 45],
      lowAltitudeInHighStructure: try t[optional: 46],
      ZMarkerAvailable: try t[optional: 47],
      TWEBHours: try t[optional: 48],
      TWEBPhone: try t[optional: 49],
      controllingFSSCode: try t[optional: 50],
      NOTAMAccountabilityCode: try t[optional: 53],
      LFRLegs: LFRLegs,
      status: try t[55],
      isPitchPoint: try t[optional: 56],
      isCatchPoint: try t[optional: 57],
      isAssociatedWithSUA: try t[optional: 58],
      hasRestriction: try t[optional: 59],
      broadcastsHIWAS: try t[optional: 60],
      hasTWEBRestriction: try t[optional: 61]
    )
    navaids[NavaidKey(navaid: navaid)] = navaid
  }

  private func parseRemark(_ values: [ArraySlice<UInt8>]) throws {
    let t = try remarkTransformer.applyTo(values),
      remarkText: String = try t[3]
    try updateNavaid(t) { navaid in
      navaid.remarks.append(remarkText)
    }
  }

  private func parseFixes(_ values: [ArraySlice<UInt8>]) throws {
    let t = try fixTransformer.applyTo(values),
      firstFix: Substring = try t[3],
      // Array types need raw access and manual casting due to [Any?] covariance
      otherFixes = (t[raw: 4] as? [Any?])?.compactMap { $0 as? Substring }
    try updateNavaid(t) { navaid in
      navaid.associatedFixNames.insert(String(firstFix))
      if let otherFixes {
        for fix in otherFixes {
          navaid.associatedFixNames.insert(String(fix))
        }
      }
    }
  }

  private func parseHoldingPatterns(_ values: [ArraySlice<UInt8>]) throws {
    let t = try holdingPatternTransformer.applyTo(values),
      patternName: String = try t[3],
      patternNumber: UInt = try t[4],
      // Array types need raw access and manual casting due to [Any?] covariance
      otherPatterns = (t[raw: 5] as? [Any?])?.compactMap { $0 as? HoldingPatternId }
    try updateNavaid(t) { navaid in
      let pattern = HoldingPatternId(name: patternName, number: patternNumber)
      navaid.associatedHoldingPatterns.insert(pattern)

      if let otherPatterns {
        for pattern in otherPatterns {
          navaid.associatedHoldingPatterns.insert(pattern)
        }
      }
    }
  }

  private func parseFanMarkers(_ values: [ArraySlice<UInt8>]) throws {
    let t = try fanMarkerTransformer.applyTo(values),
      firstMarker: String = try t[3],
      // Array types need raw access and manual casting due to [Any?] covariance
      otherMarkers = (t[raw: 4] as? [Any?])?.compactMap { $0 as? String }
    try updateNavaid(t) { navaid in
      navaid.fanMarkers.insert(firstMarker)
      if let otherMarkers {
        for fanMarker in otherMarkers {
          navaid.fanMarkers.insert(fanMarker)
        }
      }
    }
  }

  private func parseCheckpoint(_ values: [ArraySlice<UInt8>]) throws {
    let t = try checkpointTransformer.applyTo(values),
      bearingValue: UInt = try t[4]
    try updateNavaid(t) { navaid in
      let bearing = Bearing(
        bearingValue,
        reference: .magnetic,
        magneticVariationDeg: navaid.magneticVariationDeg ?? 0
      )
      let checkpoint = VORCheckpoint(
        type: try t[3],
        bearing: bearing,
        altitudeFtMSL: try t[optional: 5],
        airportId: try t[optional: 6],
        stateCode: try t[7],
        airDescription: try t[optional: 8],
        groundDescription: try t[optional: 9]
      )
      navaid.checkpoints.append(checkpoint)
    }
  }

  private func updateNavaid(_ t: FixedWidthTransformedRow, process: (inout Navaid) throws -> Void)
    throws
  {
    let navaidID: String = try t[1]
    let navaidType: Navaid.FacilityType = try t[2]

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
