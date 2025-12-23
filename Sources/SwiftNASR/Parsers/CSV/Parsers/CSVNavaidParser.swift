import Foundation
import StreamingCSV

/// CSV Navaid Parser using declarative transformers like FixedWidthNavaidParser
actor CSVNavaidParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["NAV_BASE.csv", "NAV_RMK.csv", "NAV_CKPT.csv"]

  var navaids = [NavaidKey: Navaid]()

  // Transformer with named fields for header-based parsing
  private let basicTransformer = CSVTransformer([
    .init("EFF_DATE", .null),
    .init("NAV_ID", .string()),
    .init("NAV_TYPE", .recordEnum(Navaid.FacilityType.self)),
    .init("NAME", .string(nullable: .blank)),
    .init("CITY", .string(nullable: .blank)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("STATE_NAME", .string(nullable: .blank)),
    .init("REGION_CODE", .string(nullable: .blank)),
    .init("COUNTRY_NAME", .string(nullable: .blank)),
    .init("COUNTRY_CODE", .string(nullable: .blank)),
    .init("OWNER", .generic({ stripOwnerTypePrefix($0) }, nullable: .blank)),
    .init("OPERATOR", .generic({ stripOwnerTypePrefix($0) }, nullable: .blank)),
    .init("NAS_USE_FLAG", .boolean()),
    .init("PUBLIC_USE_FLAG", .boolean()),
    .init("NDB_CLASS_CODE", .generic({ try parseClassDesignator($0) }, nullable: .blank)),
    .init("OPER_HOURS", .string(nullable: .blank)),
    .init("HIGH_ALT_ARTCC_ID", .string(nullable: .blank)),
    .init("LOW_ALT_ARTCC_ID", .string(nullable: .blank)),
    .init("LAT_DECIMAL", .float(nullable: .blank)),
    .init("LONG_DECIMAL", .float(nullable: .blank)),
    .init("SURVEY_ACCURACY_CODE", .generic({ try parseSurveyAccuracy($0) }, nullable: .blank)),
    .init("TACAN_DME_LAT_DECIMAL", .float(nullable: .blank)),
    .init("TACAN_DME_LONG_DECIMAL", .float(nullable: .blank)),
    .init("ELEV", .float(nullable: .blank)),
    .init("MAG_VARN", .float(nullable: .blank)),
    .init("MAG_VARN_HEMIS", .string(nullable: .blank)),
    .init("MAG_VARN_YEAR", .dateComponents(format: .yearOnly, nullable: .blank)),
    .init("SIMUL_VOICE_FLAG", .boolean(nullable: .blank)),
    .init("PWR_OUTPUT", .unsignedInteger(nullable: .sentinel(["N", ""]))),
    .init("AUTO_VOICE_ID_FLAG", .boolean(nullable: .blank)),
    .init("MNT_CAT_CODE", .recordEnum(Navaid.MonitoringCategory.self, nullable: .blank)),
    .init("VOICE_CALL", .string(nullable: .sentinel(["", "NONE"]))),
    .init("CHAN", .generic({ try parseTACAN($0, fieldIndex: 34) }, nullable: .blank)),
    .init("FREQ", .string(nullable: .blank)),  // raw string - converted to Hz based on navaid type
    .init("MKR_IDENT", .string(nullable: .blank)),
    .init(
      "MKR_SHAPE",
      .generic(
        { str in
          switch str.uppercased() {
            case "E": return Navaid.FanMarkerType.elliptical
            case "B": return Navaid.FanMarkerType.bone
            case "": return nil
            default: return Navaid.FanMarkerType.for(str)
          }
        },
        nullable: .blank
      )
    ),
    .init("MKR_BRG", .unsignedInteger(nullable: .blank)),
    .init("ALT_CODE", .generic({ try parseServiceVolume($0) }, nullable: .blank)),
    .init("DME_SSV", .generic({ try parseServiceVolume($0) }, nullable: .blank)),
    .init("NAV_STATUS", .recordEnum(OperationalStatus.self, nullable: .blank)),
    .init("LOW_NAV_ON_HIGH_CHART_FLAG", .boolean(nullable: .blank)),
    .init("Z_MKR_FLAG", .boolean(nullable: .blank)),
    .init("FSS_ID", .string(nullable: .blank)),
    .init("NOTAM_ID", .string(nullable: .blank)),
    .init("PITCH_FLAG", .boolean(nullable: .blank)),
    .init("CATCH_FLAG", .boolean(nullable: .blank)),
    .init("SUA_ATCAA_FLAG", .boolean(nullable: .blank)),
    .init("RESTRICTION_FLAG", .boolean(nullable: .blank)),
    .init("HIWAS_FLAG", .boolean(nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse NAV_BASE.csv
    try await parseCSVFile(
      filename: "NAV_BASE.csv",
      requiredColumns: ["NAV_ID", "NAV_TYPE", "LAT_DECIMAL", "LONG_DECIMAL"]
    ) { row in
      let t = try self.basicTransformer.applyTo(row)

      // Parse location - convert from decimal degrees to arc-seconds
      let latDecimal: Float? = try t[optional: "LAT_DECIMAL"]
      let lonDecimal: Float? = try t[optional: "LONG_DECIMAL"]
      let position = Location(
        latitudeArcsec: (latDecimal ?? 0) * 3600,
        longitudeArcsec: (lonDecimal ?? 0) * 3600,
        elevationFtMSL: try t[optional: "ELEV"]
      )

      // Parse TACAN position if available - convert from decimal degrees to arc-seconds
      let TACANPosition: Location? = {
        let TACANLat: Float? = try? t[optional: "TACAN_DME_LAT_DECIMAL"]
        let TACANLon: Float? = try? t[optional: "TACAN_DME_LONG_DECIMAL"]
        if let TACANLat, let TACANLon, TACANLat != 0 || TACANLon != 0 {
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
        let magVar: Float? = try? t[optional: "MAG_VARN"]
        let hemisphere: String? = try? t[optional: "MAG_VARN_HEMIS"]
        if let magVar, let hemisphere, !hemisphere.isEmpty {
          let magVarStr = "\(Int(magVar))\(hemisphere)"
          return try? parseMagVar(magVarStr, fieldIndex: 26)
        }
        return nil
      }()

      // Convert fan marker bearing to Bearing<UInt>
      let fanMarkerBearing: UInt? = try t[optional: "MKR_BRG"]
      let fanMarkerMajorBearing = fanMarkerBearing.map { value in
        Bearing(value, reference: .magnetic, magneticVariationDeg: magneticVariationDeg ?? 0)
      }

      // Convert frequency to Hz based on navaid type
      let navaidType: Navaid.FacilityType = try t["NAV_TYPE"]
      let rawFreq: String? = try t[optional: "FREQ"]
      let frequencyHz = parseNavaidFrequencyToHz(rawFreq, navaidType: navaidType)

      let navaid = Navaid(
        id: try t["NAV_ID"],
        name: try t[optional: "NAME"] ?? "",
        type: navaidType,
        city: try t[optional: "CITY"] ?? "",
        stateName: try t[optional: "STATE_NAME"],
        FAARegion: try t[optional: "REGION_CODE"] ?? "",
        country: try t[optional: "COUNTRY_NAME"],
        ownerName: try t[optional: "OWNER"],
        operatorName: try t[optional: "OPERATOR"],
        commonSystemUsage: try t[optional: "NAS_USE_FLAG"] ?? false,
        publicUse: try t[optional: "PUBLIC_USE_FLAG"] ?? false,
        navaidClass: try t[optional: "NDB_CLASS_CODE"],
        hoursOfOperation: try t[optional: "OPER_HOURS"],
        highAltitudeARTCCCode: try t[optional: "HIGH_ALT_ARTCC_ID"],
        lowAltitudeARTCCCode: try t[optional: "LOW_ALT_ARTCC_ID"],
        position: position,
        TACANPosition: TACANPosition,
        surveyAccuracy: try t[optional: "SURVEY_ACCURACY_CODE"],
        magneticVariationDeg: magneticVariationDeg,
        magneticVariationEpochComponents: try t[optional: "MAG_VARN_YEAR"],
        simultaneousVoice: try t[optional: "SIMUL_VOICE_FLAG"],
        powerOutputW: try t[optional: "PWR_OUTPUT"],
        automaticVoiceId: try t[optional: "AUTO_VOICE_ID_FLAG"],
        monitoringCategory: try t[optional: "MNT_CAT_CODE"],
        radioVoiceCall: try t[optional: "VOICE_CALL"],
        tacanChannel: try t[optional: "CHAN"],
        frequencyHz: frequencyHz,
        beaconIdentifier: try t[optional: "MKR_IDENT"],
        fanMarkerType: try t[optional: "MKR_SHAPE"],
        fanMarkerMajorBearing: fanMarkerMajorBearing,
        VORServiceVolume: try t[optional: "ALT_CODE"],
        DMEServiceVolume: try t[optional: "DME_SSV"],
        lowAltitudeInHighStructure: try t[optional: "LOW_NAV_ON_HIGH_CHART_FLAG"],
        ZMarkerAvailable: try t[optional: "Z_MKR_FLAG"],
        TWEBHours: nil,  // Not in CSV
        TWEBPhone: nil,  // Not in CSV
        controllingFSSCode: try t[optional: "FSS_ID"],
        NOTAMAccountabilityCode: try t[optional: "NOTAM_ID"],
        LFRLegs: nil,  // Not in CSV
        status: try t[optional: "NAV_STATUS"] ?? .operationalIFR,
        isPitchPoint: try t[optional: "PITCH_FLAG"],
        isCatchPoint: try t[optional: "CATCH_FLAG"],
        isAssociatedWithSUA: try t[optional: "SUA_ATCAA_FLAG"],
        hasRestriction: try t[optional: "RESTRICTION_FLAG"],
        broadcastsHIWAS: try t[optional: "HIWAS_FLAG"],
        hasTWEBRestriction: nil  // Not in CSV
      )

      let key = NavaidKey(navaid: navaid)
      self.navaids[key] = navaid
    }

    // Parse NAV_RMK.csv for remarks
    try await parseCSVFile(
      filename: "NAV_RMK.csv",
      requiredColumns: ["NAV_ID", "NAV_TYPE", "REMARK"]
    ) { row in
      let navID = try row["NAV_ID"]
      let navTypeStr = try row["NAV_TYPE"]
      let city = row[ifExists: "CITY"] ?? ""
      let remark = try row["REMARK"]

      guard !navID.isEmpty, !remark.isEmpty else { return }

      // Parse navaid type
      guard let navType = Navaid.FacilityType.for(navTypeStr) else { return }

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
    try await parseCSVFile(
      filename: "NAV_CKPT.csv",
      requiredColumns: ["NAV_ID", "NAV_TYPE", "BRG", "AIR_GND_CODE"]
    ) { row in
      let navID = try row["NAV_ID"]
      let navTypeStr = try row["NAV_TYPE"]
      let city = row[ifExists: "CITY"] ?? ""

      guard !navID.isEmpty else { return }

      // Parse navaid type
      guard let navType = Navaid.FacilityType.for(navTypeStr) else { return }

      // Find the navaid
      let matchingKey = self.navaids.keys.first { key in
        key.ID == navID && key.type == navType && (key.city == city || key.city.isEmpty)
      }

      guard let key = matchingKey else { return }

      // Parse checkpoint fields
      let altitudeStr = row[ifExists: "ALTITUDE"] ?? ""
      let bearingStr = try row["BRG"]
      let airGndCode = try row["AIR_GND_CODE"]
      let description = row[ifExists: "CHK_DESC"] ?? ""
      let airportId = row[ifExists: "ARPT_ID"] ?? ""
      let stateCode = row[ifExists: "STATE_CHK_CODE"] ?? ""

      // Parse checkpoint type
      guard let checkpointType = VORCheckpoint.CheckpointType.for(airGndCode) else { return }

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
