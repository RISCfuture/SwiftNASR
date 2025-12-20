import Foundation
import StreamingCSV

/// CSV Hold Parser for HPF (Holding Pattern) files.
///
/// Parses holding pattern data from CSV files: `HPF_BASE.csv`, `HPF_CHRT.csv`,
/// `HPF_SPD_ALT.csv`, and `HPF_RMK.csv`.
actor CSVHoldParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["HPF_BASE.csv", "HPF_CHRT.csv", "HPF_SPD_ALT.csv", "HPF_RMK.csv"]

  var holds = [String: Hold]()

  // Transformer for base fields
  private let baseTransformer = CSVTransformer([
    .dateComponents(format: .yearMonthDaySlash, nullable: .blank),  // 0: EFF_DATE
    .string(),  // 1: HP_NAME
    .unsignedInteger(nullable: .blank),  // 2: HP_NO
    .string(nullable: .blank),  // 3: STATE_CODE
    .string(nullable: .blank),  // 4: COUNTRY_CODE
    .string(nullable: .blank),  // 5: FIX_ID
    .string(nullable: .blank),  // 6: ICAO_REGION_CODE
    .string(nullable: .blank),  // 7: NAV_ID
    .string(nullable: .blank),  // 8: NAV_TYPE (raw string for later parsing)
    .generic({ CardinalDirection.for($0) }, nullable: .blank),  // 9: HOLD_DIRECTION
    // 10: HOLD_DEG_OR_CRS - some records have cardinal directions instead of numbers (data entry errors)
    .unsignedInteger(nullable: .sentinel(["", "N", "S", "E", "W", "NE", "NW", "SE", "SW"])),
    .generic({ Hold.AzimuthType.for($0) }, nullable: .blank),  // 11: AZIMUTH
    .unsignedInteger(nullable: .blank),  // 12: COURSE_INBOUND_DEG
    .generic({ parseTurnDirection($0) }, nullable: .blank),  // 13: TURN_DIRECTION
    .unsignedInteger(nullable: .blank)  // 14: LEG_LENGTH_DIST
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse HPF_BASE.csv - base holding pattern data
    try await parseCSVFile(filename: "HPF_BASE.csv", expectedFieldCount: 15) { fields in
      guard fields.count >= 13 else { return }

      let transformedValues = try self.baseTransformer.applyTo(fields, indices: Array(0..<15))

      let name = transformedValues[1] as! String
      guard let patternNumber = transformedValues[2] as? UInt else { return }

      let holdKey = "\(name)-\(patternNumber)"

      // Parse navaid facility type from raw string
      let navaidTypeStr = fields[8].trimmingCharacters(in: .whitespaces)
      let navaidFacilityType: Navaid.FacilityType? =
        if navaidTypeStr.isEmpty {
          nil
        } else {
          Navaid.FacilityType.for(navaidTypeStr)
        }

      // Create hold with base data
      // CSV format doesn't include position data, so fixPosition and navaidPosition are nil
      let hold = Hold(
        name: name,
        patternNumber: patternNumber,
        effectiveDateComponents: transformedValues[0] as? DateComponents,
        holdingDirection: transformedValues[9] as? CardinalDirection,
        magneticBearingDeg: transformedValues[10] as? UInt,
        azimuthType: transformedValues[11] as? Hold.AzimuthType,
        ILSFacilityIdentifier: nil,  // Not in CSV format
        ilsFacilityType: nil,  // Not in CSV format
        navaidIdentifier: (transformedValues[7] as? String)?.isEmpty == false
          ? transformedValues[7] as? String : nil,
        navaidFacilityType: navaidFacilityType,
        additionalFacility: nil,  // Not in CSV format
        inboundCourseDeg: transformedValues[12] as? UInt,
        turnDirection: transformedValues[13] as? LateralDirection,
        altitudes: try HoldingAltitudes(
          allAircraft: nil,
          speed170to175kt: nil,
          speed200to230kt: nil,
          speed265kt: nil,
          speed280kt: nil,
          speed310kt: nil
        ),
        fixIdentifier: (transformedValues[5] as? String)?.isEmpty == false
          ? transformedValues[5] as? String : nil,
        fixStateCode: (transformedValues[3] as? String)?.isEmpty == false
          ? transformedValues[3] as? String : nil,
        fixICAORegion: (transformedValues[6] as? String)?.isEmpty == false
          ? transformedValues[6] as? String : nil,
        fixARTCC: nil,  // Not in CSV format
        fixPosition: nil,  // Not in CSV format
        navaidHighRouteARTCC: nil,  // Not in CSV format
        navaidLowRouteARTCC: nil,  // Not in CSV format
        navaidPosition: nil,  // Not in CSV format
        legTimeMin: nil,  // CSV only has distance
        legDistanceNM: (transformedValues[14] as? UInt).map { Double($0) }
      )

      self.holds[holdKey] = hold
    }

    // Parse HPF_CHRT.csv - charting information
    try await parseCSVFile(filename: "HPF_CHRT.csv", expectedFieldCount: 6) { fields in
      guard fields.count >= 6 else { return }

      let name = fields[1].trimmingCharacters(in: .whitespaces)
      guard let patternNumber = UInt(fields[2].trimmingCharacters(in: .whitespaces)) else { return }

      let holdKey = "\(name)-\(patternNumber)"

      guard self.holds[holdKey] != nil else { return }

      let chartingType = fields[5].trimmingCharacters(in: .whitespaces)
      if !chartingType.isEmpty {
        self.holds[holdKey]?.chartingInfo.append(chartingType)
      }
    }

    // Parse HPF_SPD_ALT.csv - speed/altitude information
    // Collect altitude data by hold key, then update holds after
    var altitudesByHold = [String: [String: String]]()  // holdKey -> speedRange -> altitude

    try await parseCSVFile(filename: "HPF_SPD_ALT.csv", expectedFieldCount: 7) { fields in
      guard fields.count >= 7 else { return }

      let name = fields[1].trimmingCharacters(in: .whitespaces)
      guard let patternNumber = UInt(fields[2].trimmingCharacters(in: .whitespaces)) else { return }

      let holdKey = "\(name)-\(patternNumber)"

      guard self.holds[holdKey] != nil else { return }

      let speedRange = fields[5].trimmingCharacters(in: .whitespaces)
      let altitude = fields[6].trimmingCharacters(in: .whitespaces)

      if !speedRange.isEmpty && !altitude.isEmpty {
        if altitudesByHold[holdKey] == nil {
          altitudesByHold[holdKey] = [:]
        }
        altitudesByHold[holdKey]?[speedRange] = altitude
      }
    }

    // Update holds with collected altitude data
    for (holdKey, altitudes) in altitudesByHold {
      guard self.holds[holdKey] != nil else { continue }

      // Map speed ranges to HoldingAltitudes
      // CSV speed ranges: "170", "175", "200", "230", "265", "280", "310", or unspecified for "ALL"
      let speed170 = altitudes["170"] ?? altitudes["175"]
      let speed200 = altitudes["200"] ?? altitudes["230"]
      let speed265 = altitudes["265"]
      let speed280 = altitudes["280"]
      let speed310 = altitudes["310"]
      let allAircraft = altitudes["ALL"] ?? altitudes[""]

      do {
        let holdingAltitudes = try HoldingAltitudes(
          allAircraft: allAircraft,
          speed170to175kt: speed170,
          speed200to230kt: speed200,
          speed265kt: speed265,
          speed280kt: speed280,
          speed310kt: speed310
        )

        // Create updated hold with new altitudes
        if let hold = self.holds[holdKey] {
          self.holds[holdKey] = Hold(
            name: hold.name,
            patternNumber: hold.patternNumber,
            effectiveDateComponents: hold.effectiveDateComponents,
            holdingDirection: hold.holdingDirection,
            magneticBearingDeg: hold.magneticBearingDeg,
            azimuthType: hold.azimuthType,
            ILSFacilityIdentifier: hold.ILSFacilityIdentifier,
            ilsFacilityType: hold.ilsFacilityType,
            navaidIdentifier: hold.navaidIdentifier,
            navaidFacilityType: hold.navaidFacilityType,
            additionalFacility: hold.additionalFacility,
            inboundCourseDeg: hold.inboundCourseDeg,
            turnDirection: hold.turnDirection,
            altitudes: holdingAltitudes,
            fixIdentifier: hold.fixIdentifier,
            fixStateCode: hold.fixStateCode,
            fixICAORegion: hold.fixICAORegion,
            fixARTCC: hold.fixARTCC,
            fixPosition: hold.fixPosition,
            navaidHighRouteARTCC: hold.navaidHighRouteARTCC,
            navaidLowRouteARTCC: hold.navaidLowRouteARTCC,
            navaidPosition: hold.navaidPosition,
            legTimeMin: hold.legTimeMin,
            legDistanceNM: hold.legDistanceNM
          )
          // Preserve mutable arrays
          self.holds[holdKey]?.chartingInfo = hold.chartingInfo
          self.holds[holdKey]?.otherAltitudeSpeed = hold.otherAltitudeSpeed
          self.holds[holdKey]?.remarks = hold.remarks
        }
      } catch {
        // If altitude parsing fails, keep the original hold with empty altitudes
        continue
      }
    }

    // Parse HPF_RMK.csv - remarks
    try await parseCSVFile(filename: "HPF_RMK.csv", expectedFieldCount: 9) { fields in
      guard fields.count >= 9 else { return }

      let name = fields[1].trimmingCharacters(in: .whitespaces)
      guard let patternNumber = UInt(fields[2].trimmingCharacters(in: .whitespaces)) else { return }

      let holdKey = "\(name)-\(patternNumber)"

      guard self.holds[holdKey] != nil else { return }

      let fieldLabel = fields[6].trimmingCharacters(in: .whitespaces)  // REF_COL_NAME
      let remarkText = fields[8].trimmingCharacters(in: .whitespaces)  // REMARK

      if !remarkText.isEmpty {
        let remark = FieldRemark(fieldLabel: fieldLabel, text: remarkText)
        self.holds[holdKey]?.remarks.append(remark)
      }
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(holds: Array(holds.values))
  }
}

/// Parses turn direction from string (L/R).
private func parseTurnDirection(_ str: String) -> LateralDirection? {
  switch str.uppercased() {
    case "L": return .left
    case "R": return .right
    default: return nil
  }
}
