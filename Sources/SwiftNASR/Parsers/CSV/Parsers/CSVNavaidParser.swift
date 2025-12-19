import Foundation
import StreamingCSV
import ZIPFoundation

/// CSV Navaid Parser using declarative transformers like FixedWidthNavaidParser
actor CSVNavaidParser: CSVParser {
  var CSVDirectory = URL(fileURLWithPath: "/")
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["NAV_BASE.csv", "NAV_RMK.csv", "NAV_CKPT.csv"]

  var navaids = [NavaidKey: Navaid]()

  // CSV field mapping based on NAV_BASE.csv headers (0-based indices)
  // Index mapping from CSV columns to transformer array positions
  private let CSVFieldMapping: [Int] = [
    0,  // 0: EFF_DATE -> effective date
    1,  // 1: NAV_ID -> ID
    2,  // 2: NAV_TYPE -> facility typegit
    7,  // 3: NAME -> name
    4,  // 4: CITY -> city
    3,  // 5: STATE_CODE -> state PO code
    8,  // 6: STATE_NAME -> state name
    9,  // 7: REGION_CODE -> FAA region
    10,  // 8: COUNTRY_NAME -> country
    5,  // 9: COUNTRY_CODE -> country PO code
    12,  // 10: OWNER -> owner name
    13,  // 11: OPERATOR -> operator name
    14,  // 12: NAS_USE_FLAG -> common use
    15,  // 13: PUBLIC_USE_FLAG -> public use
    16,  // 14: NDB_CLASS_CODE -> navaid class
    17,  // 15: OPER_HOURS -> hours of operation
    18,  // 16: HIGH_ALT_ARTCC_ID -> ARTCC ID
    19,  // 17: HIGH_ARTCC_NAME -> ARTCC name
    20,  // 18: LOW_ALT_ARTCC_ID -> ARTCC sec ID
    21,  // 19: LOW_ARTCC_NAME -> ARTCC sec name
    26,  // 20: LAT_DECIMAL -> lat decimal (field 26 not 25)
    31,  // 21: LONG_DECIMAL -> lon decimal (field 31 not 30)
    32,  // 22: SURVEY_ACCURACY_CODE -> survey accuracy
    38,  // 23: TACAN_DME_LAT_DECIMAL -> tacan lat decimal
    43,  // 24: TACAN_DME_LONG_DECIMAL -> tacan lon decimal
    44,  // 25: ELEV -> elevation (field 44)
    45,  // 26: MAG_VARN -> mag var value (field 45)
    46,  // 27: MAG_VARN_HEMIS -> mag var hemisphere (field 46)
    47,  // 28: MAG_VARN_YEAR -> mag var epoch (field 47)
    48,  // 29: SIMUL_VOICE_FLAG -> simultaneous voice (field 48)
    49,  // 30: PWR_OUTPUT -> power output (field 49)
    50,  // 31: AUTO_VOICE_ID_FLAG -> automatic voice ID (field 50)
    51,  // 32: MNT_CAT_CODE -> monitoring category (field 51)
    52,  // 33: VOICE_CALL -> radio voice call (field 52)
    53,  // 34: CHAN -> channel/TACAN (field 53)
    54,  // 35: FREQ -> frequency (field 54)
    55,  // 36: MKR_IDENT -> transmitted ID/beacon ident (field 55)
    56,  // 37: MKR_SHAPE -> fan marker type (field 56)
    57,  // 38: MKR_BRG -> fan marker major bearing (field 57)
    58,  // 39: ALT_CODE -> service volume VOR (field 58)
    59,  // 40: DME_SSV -> service volume DME (field 59)
    6,  // 41: NAV_STATUS -> operational status
    60,  // 42: LOW_NAV_ON_HIGH_CHART_FLAG -> low altitude in high structure
    61,  // 43: Z_MKR_FLAG -> Z marker available
    62,  // 44: FSS_ID -> controlling FSS code
    65,  // 45: NOTAM_ID -> NOTAM accountability code
    67,  // 46: pitch flag
    68,  // 47: catch flag
    69,  // 48: sua flag
    70,  // 49: navaid restriction flag
    71  // 50: hiwas flag
  ]

  // Transformer matching FixedWidthNavaidParser field types
  private let basicTransformer = CSVTransformer([
    .null,  //  0 effective date
    .string(),  //  1 ID
    .generic { try raw($0, toEnum: Navaid.FacilityType.self) },  //  2 facility type
    .string(nullable: .blank),  //  3 name
    .string(nullable: .blank),  //  4 city
    .string(nullable: .blank),  //  5 state PO code
    .string(nullable: .blank),  //  6 state name
    .string(nullable: .blank),  //  7 FAA region
    .string(nullable: .blank),  //  8 country
    .string(nullable: .blank),  //  9 country PO code
    .generic({ stripOwnerTypePrefix($0) }, nullable: .blank),  // 10 owner name (strip X- prefix)
    .generic({ stripOwnerTypePrefix($0) }, nullable: .blank),  // 11 operator name (strip X- prefix)
    .boolean(),  // 12 common use
    .boolean(),  // 13 public use
    .generic({ try parseClassDesignator($0) }, nullable: .blank),  // 14 navaid class
    .string(nullable: .blank),  // 15 hours of operation
    .string(nullable: .blank),  // 16 ARTCC ID
    .null,  // 17 ARTCC name
    .string(nullable: .blank),  // 18 ARTCC sec ID
    .null,  // 19 ARTCC sec name
    .float(nullable: .blank),  // 20 lat - decimal
    .float(nullable: .blank),  // 21 lon - decimal
    .generic({ try parseSurveyAccuracy($0) }, nullable: .blank),  // 22 survey accuracy
    .float(nullable: .blank),  // 23 tacan lat - decimal
    .float(nullable: .blank),  // 24 tacan lon - decimal
    .float(nullable: .blank),  // 25 elevation
    .float(nullable: .blank),  // 26 mag var value (can have decimals)
    .string(nullable: .blank),  // 27 mag var hemisphere
    .dateComponents(format: .yearOnly, nullable: .blank),  // 28 mag var epoch
    .boolean(nullable: .blank),  // 29 simultaneous voice (Y/N flag)
    .unsignedInteger(nullable: .sentinel(["N", ""])),  // 30 power output ("N" or blank means not applicable)
    .boolean(nullable: .blank),  // 31 automatic voice ID (Y/N flag)
    .generic({ try raw($0, toEnum: Navaid.MonitoringCategory.self) }, nullable: .blank),  // 32 monitoring category
    .string(nullable: .sentinel(["", "NONE"])),  // 33 radio voice call
    .generic({ try parseTACAN($0, fieldIndex: 34) }, nullable: .blank),  // 34 channel/TACAN
    .frequency(nullable: .blank),  // 35 frequency
    .string(nullable: .blank),  // 36 transmitted ID/beacon ident
    .generic(
      { str in
        // Map CSV shorthand to full enum values
        switch str.uppercased() {
          case "E": return Navaid.FanMarkerType.elliptical
          case "B": return Navaid.FanMarkerType.bone
          case "": return nil
          default: return try raw(str, toEnum: Navaid.FanMarkerType.self)
        }
      },
      nullable: .blank
    ),  // 37 fan marker type
    .unsignedInteger(nullable: .blank),  // 38 fan marker major bearing (MKR_BRG)
    .generic({ try parseServiceVolume($0) }, nullable: .blank),  // 39 VOR service volume
    .generic({ try parseServiceVolume($0) }, nullable: .blank),  // 40 DME service volume
    .generic({ try raw($0, toEnum: OperationalStatus.self) }, nullable: .blank),  // 41 operational status
    .boolean(nullable: .blank),  // 42 low altitude in high structure
    .boolean(nullable: .blank),  // 43 Z marker available
    .string(nullable: .blank),  // 44 FSS ID (controlling FSS code)
    .string(nullable: .blank),  // 45 NOTAM ID (NOTAM accountability code)
    .boolean(nullable: .blank),  // 46 pitch flag
    .boolean(nullable: .blank),  // 47 catch flag
    .boolean(nullable: .blank),  // 48 sua flag
    .boolean(nullable: .blank),  // 49 navaid restriction flag
    .boolean(nullable: .blank)  // 50 hiwas flag
  ])

  func prepare(distribution: Distribution) throws {
    // Set the CSV directory for CSV distributions
    if let dirDist = distribution as? DirectoryDistribution {
      CSVDirectory = dirDist.location
    } else if let archiveDist = distribution as? ArchiveFileDistribution {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        "SwiftNASR_CSV_\(UUID().uuidString)"
      )
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      try FileManager.default.unzipItem(at: archiveDist.location, to: tempDir)
      CSVDirectory = tempDir
    }
  }

  func parse(data _: Data) async throws {
    // Parse NAV_BASE.csv
    try await parseCSVFile(filename: "NAV_BASE.csv", expectedFieldCount: 72) { fields in
      guard fields.count >= 60 else { return }

      // Map CSV fields to transformer indices
      var mappedFields = [String](repeating: "", count: 51)

      for (transformerIndex, csvIndex) in CSVFieldMapping.enumerated() {
        if csvIndex >= 0 && csvIndex < fields.count {
          mappedFields[transformerIndex] = fields[csvIndex]
        }
      }

      let transformedValues = try self.basicTransformer.applyTo(
        mappedFields,
        indices: Array(0..<51)
      )

      // Parse location - convert from decimal degrees to arc-seconds
      let position = Location(
        latitudeArcsec: (transformedValues[20] as? Float ?? 0) * 3600,
        longitudeArcsec: (transformedValues[21] as? Float ?? 0) * 3600,
        elevationFtMSL: transformedValues[25] as? Float
      )

      // Parse TACAN position if available - convert from decimal degrees to arc-seconds
      let TACANPosition: Location? = {
        if let TACANLat = transformedValues[23] as? Float,
          let TACANLon = transformedValues[24] as? Float,
          TACANLat != 0 || TACANLon != 0
        {
          return Location(
            latitudeArcsec: TACANLat * 3600,
            longitudeArcsec: TACANLon * 3600,
            elevationFtMSL: nil
          )
        }
        return nil
      }()

      // Parse mag var from transformer output (already parsed as float)
      let magneticVariationDeg: Int? = {
        if let magVar = transformedValues[26] as? Float {
          let hemisphere = mappedFields[27]
          if !hemisphere.isEmpty {
            // Combine magnitude with hemisphere for parser
            let magVarStr = "\(Int(magVar))\(hemisphere)"
            return try? parseMagVar(magVarStr, fieldIndex: 26)
          }
        }
        return nil
      }()

      // Convert fan marker bearing to Bearing<UInt>
      let fanMarkerMajorBearing = (transformedValues[38] as? UInt).map { value in
        Bearing(value, reference: .magnetic, magneticVariationDeg: magneticVariationDeg ?? 0)
      }

      let navaid = Navaid(
        id: transformedValues[1] as! String,
        name: transformedValues[3] as? String ?? "",
        type: transformedValues[2] as! Navaid.FacilityType,
        city: transformedValues[4] as? String ?? "",
        stateName: transformedValues[6] as? String,
        FAARegion: transformedValues[7] as? String ?? "",
        country: transformedValues[8] as? String,
        ownerName: transformedValues[10] as? String,
        operatorName: transformedValues[11] as? String,
        commonSystemUsage: transformedValues[12] as? Bool ?? false,
        publicUse: transformedValues[13] as? Bool ?? false,
        navaidClass: transformedValues[14] as? Navaid.NavaidClass,
        hoursOfOperation: transformedValues[15] as? String,
        highAltitudeARTCCCode: transformedValues[16] as? String,
        lowAltitudeARTCCCode: transformedValues[18] as? String,
        position: position,
        TACANPosition: TACANPosition,
        surveyAccuracy: transformedValues[22] as? Navaid.SurveyAccuracy,
        magneticVariationDeg: magneticVariationDeg,
        magneticVariationEpochComponents: transformedValues[28] as? DateComponents,
        simultaneousVoice: transformedValues[29] as? Bool,
        powerOutputW: transformedValues[30] as? UInt,
        automaticVoiceId: transformedValues[31] as? Bool,
        monitoringCategory: transformedValues[32] as? Navaid.MonitoringCategory,
        radioVoiceCall: transformedValues[33] as? String,
        tacanChannel: transformedValues[34] as? Navaid.TACANChannel,
        frequencyKHz: transformedValues[35] as? UInt,
        beaconIdentifier: transformedValues[36] as? String,
        fanMarkerType: transformedValues[37] as? Navaid.FanMarkerType,
        fanMarkerMajorBearing: fanMarkerMajorBearing,
        VORServiceVolume: transformedValues[39] as? Navaid.ServiceVolume,
        DMEServiceVolume: transformedValues[40] as? Navaid.ServiceVolume,
        lowAltitudeInHighStructure: transformedValues[42] as? Bool,
        ZMarkerAvailable: transformedValues[43] as? Bool,
        TWEBHours: nil,  // Not in CSV
        TWEBPhone: nil,  // Not in CSV
        controllingFSSCode: transformedValues[44] as? String,
        NOTAMAccountabilityCode: transformedValues[45] as? String,
        LFRLegs: nil,  // Not in CSV
        status: transformedValues[41] as? OperationalStatus ?? .operationalIFR,
        isPitchPoint: transformedValues[46] as? Bool,
        isCatchPoint: transformedValues[47] as? Bool,
        isAssociatedWithSUA: transformedValues[48] as? Bool,
        hasRestriction: transformedValues[49] as? Bool,
        broadcastsHIWAS: transformedValues[50] as? Bool,
        hasTWEBRestriction: nil  // Not in CSV
      )

      let key = NavaidKey(navaid: navaid)
      self.navaids[key] = navaid
    }

    // Parse NAV_RMK.csv for remarks
    try await parseCSVFile(filename: "NAV_RMK.csv", expectedFieldCount: 10) { fields in
      guard fields.count >= 10 else { return }

      let navID = fields[1].trimmingCharacters(in: .whitespaces)
      let navTypeStr = fields[2].trimmingCharacters(in: .whitespaces)
      let city = fields[4].trimmingCharacters(in: .whitespaces)
      let remark = fields[9].trimmingCharacters(in: .whitespaces)

      guard !navID.isEmpty, !remark.isEmpty else { return }

      // Parse navaid type
      guard let navType = try? ParserHelpers.raw(navTypeStr, toEnum: Navaid.FacilityType.self)
      else {
        return
      }

      // Find the navaid by iterating through keys (since city might not match exactly)
      let matchingKey = self.navaids.keys.first { key in
        key.ID == navID && key.type == navType && (key.city == city || key.city.isEmpty)
      }

      if let key = matchingKey, var navaid = self.navaids[key] {
        navaid.remarks.append(remark)
        self.navaids[key] = navaid
      }
    }

    // Parse NAV_CKPT.csv for VOR checkpoints
    // CSV columns: EFF_DATE, NAV_ID, NAV_TYPE, STATE_CODE, CITY, COUNTRY_CODE,
    //              ALTITUDE, BRG, AIR_GND_CODE, CHK_DESC, ARPT_ID, STATE_CHK_CODE
    try await parseCSVFile(filename: "NAV_CKPT.csv", expectedFieldCount: 12) { fields in
      guard fields.count >= 12 else { return }

      let navID = fields[1].trimmingCharacters(in: .whitespaces)
      let navTypeStr = fields[2].trimmingCharacters(in: .whitespaces)
      let city = fields[4].trimmingCharacters(in: .whitespaces)

      guard !navID.isEmpty else { return }

      // Parse navaid type
      guard let navType = try? ParserHelpers.raw(navTypeStr, toEnum: Navaid.FacilityType.self)
      else {
        return
      }

      // Find the navaid
      let matchingKey = self.navaids.keys.first { key in
        key.ID == navID && key.type == navType && (key.city == city || key.city.isEmpty)
      }

      guard let key = matchingKey else { return }

      // Parse checkpoint fields
      let altitudeStr = fields[6].trimmingCharacters(in: .whitespaces)
      let bearingStr = fields[7].trimmingCharacters(in: .whitespaces)
      let airGndCode = fields[8].trimmingCharacters(in: .whitespaces)
      let description = fields[9].trimmingCharacters(in: .whitespaces)
      let airportId = fields[10].trimmingCharacters(in: .whitespaces)
      let stateCode = fields[11].trimmingCharacters(in: .whitespaces)

      // Parse checkpoint type
      guard
        let checkpointType = try? ParserHelpers.raw(
          airGndCode,
          toEnum: VORCheckpoint.CheckpointType.self
        )
      else {
        return
      }

      // Parse bearing
      guard let bearingValue = UInt(bearingStr) else { return }

      // Get magnetic variation from the navaid for bearing conversion
      let navaid = self.navaids[key]!
      let bearing = Bearing(
        bearingValue,
        reference: .magnetic,
        magneticVariationDeg: navaid.magneticVariationDeg ?? 0
      )

      // Parse altitude (only for airborne checkpoints)
      let altitude: Int? =
        if !altitudeStr.isEmpty, let alt = Int(altitudeStr) {
          alt
        } else {
          nil
        }

      // Determine air/ground description based on checkpoint type
      let airDescription: String? = checkpointType == .air ? description : nil
      let groundDescription: String? = checkpointType != .air ? description : nil

      let checkpoint = VORCheckpoint(
        type: checkpointType,
        bearing: bearing,
        altitudeFtMSL: altitude,
        airportId: airportId.isEmpty ? nil : airportId,
        stateCode: stateCode,
        airDescription: airDescription,
        groundDescription: groundDescription
      )

      self.navaids[key]!.checkpoints.append(checkpoint)
    }

    // Note: NAV_FIX.csv and NAV_HP.csv relate to fixes and holding patterns,
    // which are separate record types (not part of the Navaid model).
  }

  func finish(data: NASRData) async {
    await data.finishParsing(navaids: Array(navaids.values))
  }
}
