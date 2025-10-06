import Foundation
import StreamingCSV
import ZIPFoundation

/// CSV Navaid Parser using declarative transformers like FixedWidthNavaidParser
class CSVNavaidParser: CSVParser {
  var csvDirectory = URL(fileURLWithPath: "/")
  var navaids = [NavaidKey: Navaid]()

  // CSV field mapping based on NAV_BASE.csv headers (0-based indices)
  // Index mapping from CSV columns to transformer array positions
  private let csvFieldMapping: [Int] = [
    0,  // 0: EFF_DATE -> effective date
    1,  // 1: NAV_ID -> ID
    2,  // 2: NAV_TYPE -> facility type
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
    // The following fields aren't in CSV but are in fixed-width
    -1,  // 42: pitch flag
    -1,  // 43: catch flag
    -1,  // 44: sua flag
    -1,  // 45: navaid restriction flag
    -1,  // 46: hiwas flag
    -1  // 47: tweb restriction flag
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
    .string(nullable: .blank),  // 10 owner name
    .string(nullable: .blank),  // 11 operator name
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
    .datetime(formatter: CSVTransformer.yearOnly, nullable: .blank),  // 28 mag var epoch
    .boolean(nullable: .sentinel(["N"])),  // 29 simultaneous voice ("N" means false)
    .unsignedInteger(nullable: .sentinel(["N"])),  // 30 power output ("N" means not applicable)
    .boolean(nullable: .sentinel(["N"])),  // 31 automatic voice ID ("N" means false)
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
    .generic({ try raw($0, toEnum: Navaid.Status.self) }, nullable: .blank),  // 41 operational status
    .boolean(nullable: .blank),  // 42 pitch flag (not in CSV)
    .boolean(nullable: .blank),  // 43 catch flag (not in CSV)
    .boolean(nullable: .blank),  // 44 sua flag (not in CSV)
    .boolean(nullable: .blank),  // 45 navaid restriction flag (not in CSV)
    .boolean(nullable: .blank),  // 46 hiwas flag (not in CSV)
    .boolean(nullable: .blank)  // 47 tweb restriction flag (not in CSV)
  ])

  func prepare(distribution: Distribution) throws {
    // Set the CSV directory for CSV distributions
    if let dirDist = distribution as? DirectoryDistribution {
      csvDirectory = dirDist.location
    } else if let archiveDist = distribution as? ArchiveFileDistribution {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        "SwiftNASR_CSV_\(UUID().uuidString)"
      )
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      try FileManager.default.unzipItem(at: archiveDist.location, to: tempDir)
      csvDirectory = tempDir
    }
  }

  func parse(data _: Data) async throws {
    // Parse NAV_BASE.csv
    try await parseCSVFile(filename: "NAV_BASE.csv", expectedFieldCount: 72) { fields in
      guard fields.count >= 60 else { return }

      // Map CSV fields to transformer indices
      var mappedFields = [String](repeating: "", count: 48)

      for (transformerIndex, csvIndex) in csvFieldMapping.enumerated() {
        if csvIndex >= 0 && csvIndex < fields.count {
          mappedFields[transformerIndex] = fields[csvIndex]
        } else if csvIndex == -1 {
          // Default values for fields not in CSV
          // All default to empty string which will be handled by transformers
          mappedFields[transformerIndex] = ""
        }
      }

      let transformedValues = try self.basicTransformer.applyTo(
        mappedFields,
        indices: Array(0..<48)
      )

      // Parse location - convert from decimal degrees to arc-seconds
      let position = Location(
        latitude: (transformedValues[20] as? Float ?? 0) * 3600,
        longitude: (transformedValues[21] as? Float ?? 0) * 3600,
        elevation: transformedValues[25] as? Float
      )

      // Parse TACAN position if available - convert from decimal degrees to arc-seconds
      let TACANPosition: Location? = {
        if let tacanLat = transformedValues[23] as? Float,
          let tacanLon = transformedValues[24] as? Float,
          tacanLat != 0 || tacanLon != 0
        {
          return Location(latitude: tacanLat * 3600, longitude: tacanLon * 3600, elevation: nil)
        }
        return nil
      }()

      // Parse mag var from transformer output (already parsed as float)
      let magneticVariation: Int? = {
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
        magneticVariation: magneticVariation,
        magneticVariationEpoch: transformedValues[28] as? Date,
        simultaneousVoice: transformedValues[29] as? Bool,
        powerOutput: transformedValues[30] as? UInt,
        automaticVoiceID: transformedValues[31] as? Bool,
        monitoringCategory: transformedValues[32] as? Navaid.MonitoringCategory,
        radioVoiceCall: transformedValues[33] as? String,
        TACANChannel: transformedValues[34] as? Navaid.TACANChannel,
        frequency: transformedValues[35] as? UInt,
        beaconIdentifier: transformedValues[36] as? String,
        fanMarkerType: transformedValues[37] as? Navaid.FanMarkerType,
        fanMarkerMajorBearing: transformedValues[38] as? UInt,
        VORServiceVolume: transformedValues[39] as? Navaid.ServiceVolume,
        DMEServiceVolume: transformedValues[40] as? Navaid.ServiceVolume,
        lowAltitudeInHighStructure: nil,  // Not in CSV
        ZMarkerAvailable: nil,  // Not in CSV
        TWEBHours: nil,  // Not in CSV
        TWEBPhone: nil,  // Not in CSV
        controllingFSSCode: nil,  // Not in CSV
        NOTAMAccountabilityCode: nil,  // Not in CSV
        LFRLegs: nil,  // Not in CSV
        status: transformedValues[41] as? Navaid.Status ?? .operationalIFR,
        pitchFlag: transformedValues[42] as? Bool ?? false,
        catchFlag: transformedValues[43] as? Bool ?? false,
        SUAFlag: transformedValues[44] as? Bool ?? false,
        restrictionFlag: transformedValues[45] as? Bool,
        HIWASFlag: transformedValues[46] as? Bool,
        TWEBRestrictionFlag: transformedValues[47] as? Bool
      )

      let key = NavaidKey(navaid: navaid)
      self.navaids[key] = navaid
    }

    // TODO: Parse NAV_RMK.csv for remarks
    // TODO: Parse NAV_FIX.csv for fixes
    // TODO: Parse NAV_HP.csv for holding patterns
  }

  func finish(data: NASRData) async {
    await data.finishParsing(navaids: Array(navaids.values))
  }
}
