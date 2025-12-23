import Foundation

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

  // Transformer for base fields using named columns
  private let baseTransformer = CSVTransformer([
    .init("EFF_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("HP_NAME", .string()),
    .init("HP_NO", .unsignedInteger(nullable: .blank)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("COUNTRY_CODE", .string(nullable: .blank)),
    .init("FIX_ID", .string(nullable: .blank)),
    .init("ICAO_REGION_CODE", .string(nullable: .blank)),
    .init("NAV_ID", .string(nullable: .blank)),
    .init("NAV_TYPE", .string(nullable: .blank)),
    .init("HOLD_DIRECTION", .generic({ CardinalDirection.for($0) }, nullable: .blank)),
    // Some records have cardinal directions instead of numbers (data entry errors)
    .init(
      "HOLD_DEG_OR_CRS",
      .unsignedInteger(nullable: .sentinel(["", "N", "S", "E", "W", "NE", "NW", "SE", "SW"]))
    ),
    .init("AZIMUTH", .generic({ Hold.AzimuthType.for($0) }, nullable: .blank)),
    .init("COURSE_INBOUND_DEG", .unsignedInteger(nullable: .blank)),
    .init("TURN_DIRECTION", .generic({ try parseTurnDirection($0) }, nullable: .blank)),
    .init("LEG_LENGTH_DIST", .unsignedInteger(nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse HPF_BASE.csv - base holding pattern data
    try await parseCSVFile(
      filename: "HPF_BASE.csv",
      requiredColumns: ["HP_NAME", "HP_NO"]
    ) { row in
      let t = try self.baseTransformer.applyTo(row)

      let name: String = try t["HP_NAME"]
      guard let patternNumber: UInt = try t[optional: "HP_NO"] else { return }

      let holdKey = "\(name)-\(patternNumber)"

      // Parse navaid facility type from raw string
      let navaidTypeStr: String = try t[optional: "NAV_TYPE"] ?? ""
      let navaidFacilityType: Navaid.FacilityType? =
        if navaidTypeStr.isEmpty {
          nil
        } else {
          Navaid.FacilityType.for(navaidTypeStr)
        }

      // Get optional string values
      let navaidId: String? = try t[optional: "NAV_ID"]
      let fixId: String? = try t[optional: "FIX_ID"]
      let stateCode: String? = try t[optional: "STATE_CODE"]
      let icaoRegion: String? = try t[optional: "ICAO_REGION_CODE"]
      let legDistance: UInt? = try t[optional: "LEG_LENGTH_DIST"]

      // Create hold with base data
      // CSV format doesn't include position data, so fixPosition and navaidPosition are nil
      let hold = Hold(
        name: name,
        patternNumber: patternNumber,
        effectiveDateComponents: try t[optional: "EFF_DATE"],
        holdingDirection: try t[optional: "HOLD_DIRECTION"],
        magneticBearingDeg: try t[optional: "HOLD_DEG_OR_CRS"],
        azimuthType: try t[optional: "AZIMUTH"],
        ILSFacilityIdentifier: nil,  // Not in CSV format
        ilsFacilityType: nil,  // Not in CSV format
        navaidIdentifier: navaidId?.isEmpty == false ? navaidId : nil,
        navaidFacilityType: navaidFacilityType,
        additionalFacility: nil,  // Not in CSV format
        inboundCourseDeg: try t[optional: "COURSE_INBOUND_DEG"],
        turnDirection: try t[optional: "TURN_DIRECTION"],
        altitudes: try HoldingAltitudes(
          allAircraft: nil,
          speed170to175kt: nil,
          speed200to230kt: nil,
          speed265kt: nil,
          speed280kt: nil,
          speed310kt: nil
        ),
        fixIdentifier: fixId?.isEmpty == false ? fixId : nil,
        fixStateCode: stateCode?.isEmpty == false ? stateCode : nil,
        fixICAORegion: icaoRegion?.isEmpty == false ? icaoRegion : nil,
        fixARTCC: nil,  // Not in CSV format
        fixPosition: nil,  // Not in CSV format
        navaidHighRouteARTCC: nil,  // Not in CSV format
        navaidLowRouteARTCC: nil,  // Not in CSV format
        navaidPosition: nil,  // Not in CSV format
        legTimeMin: nil,  // CSV only has distance
        legDistanceNM: legDistance.map { Double($0) }
      )

      self.holds[holdKey] = hold
    }

    // Parse HPF_CHRT.csv - charting information
    try await parseCSVFile(
      filename: "HPF_CHRT.csv",
      requiredColumns: ["HP_NAME", "HP_NO"]
    ) { row in
      let name = try row["HP_NAME"]
      guard let patternNumber = UInt(try row["HP_NO"]) else { return }

      let holdKey = "\(name)-\(patternNumber)"

      guard self.holds[holdKey] != nil else { return }

      if let chartingType = row[ifExists: "CHARTING_TYPE_DESC"], !chartingType.isEmpty {
        self.holds[holdKey]?.chartingInfo.append(chartingType)
      }
    }

    // Parse HPF_SPD_ALT.csv - speed/altitude information
    // Collect altitude data by hold key, then update holds after
    var altitudesByHold = [String: [String: String]]()  // holdKey -> speedRange -> altitude

    try await parseCSVFile(
      filename: "HPF_SPD_ALT.csv",
      requiredColumns: ["HP_NAME", "HP_NO"]
    ) { row in
      let name = try row["HP_NAME"]
      guard let patternNumber = UInt(try row["HP_NO"]) else { return }

      let holdKey = "\(name)-\(patternNumber)"

      guard self.holds[holdKey] != nil else { return }

      let speedRange = row[ifExists: "SPEED_RANGE"] ?? ""
      let altitude = row[ifExists: "ALTITUDE"] ?? ""

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
    try await parseCSVFile(
      filename: "HPF_RMK.csv",
      requiredColumns: ["HP_NAME", "HP_NO"]
    ) { row in
      let name = try row["HP_NAME"]
      guard let patternNumber = UInt(try row["HP_NO"]) else { return }

      let holdKey = "\(name)-\(patternNumber)"

      guard self.holds[holdKey] != nil else { return }

      let fieldLabel = row[ifExists: "REF_COL_NAME"] ?? ""
      let remarkText = row[ifExists: "REMARK"] ?? ""

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
private func parseTurnDirection(_ str: String) throws -> LateralDirection {
  switch str.uppercased() {
    case "L": return .left
    case "R": return .right
    default: throw ParserError.unknownRecordEnumValue(str)
  }
}
