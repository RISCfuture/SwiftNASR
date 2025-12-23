import Foundation

/// CSV Fix Parser for parsing FIX_BASE.csv, FIX_NAV.csv, and FIX_CHRT.csv
actor CSVFixParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["FIX_BASE.csv", "FIX_NAV.csv", "FIX_CHRT.csv"]

  var fixes = [FixKey: Fix]()

  private let baseTransformer = CSVTransformer([
    .init("EFF_DATE", .null),
    .init("FIX_ID", .string()),
    .init("ICAO_REGION_CODE", .string(nullable: .blank)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("COUNTRY_CODE", .string(nullable: .blank)),
    .init("LAT_DECIMAL", .float(nullable: .blank)),
    .init("LONG_DECIMAL", .float(nullable: .blank)),
    .init("FIX_ID_OLD", .string(nullable: .blank)),
    .init("CHARTING_REMARK", .string(nullable: .blank)),
    .init("FIX_USE_CODE", .generic({ try parseFixUse($0) }, nullable: .blank)),
    .init("ARTCC_ID_HIGH", .string(nullable: .blank)),
    .init("ARTCC_ID_LOW", .string(nullable: .blank)),
    .init("PITCH_FLAG", .boolean()),
    .init("CATCH_FLAG", .boolean()),
    .init("SUA_ATCAA_FLAG", .boolean())
  ])

  private let navTransformer = CSVTransformer([
    .init("EFF_DATE", .null),
    .init("FIX_ID", .string()),
    .init("ICAO_REGION_CODE", .string(nullable: .blank)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("COUNTRY_CODE", .string(nullable: .blank)),
    .init("NAV_ID", .string()),
    .init("NAV_TYPE", .string()),
    .init("BEARING", .float(nullable: .blank)),
    .init("DISTANCE", .float(nullable: .blank))
  ])

  private let chartTransformer = CSVTransformer([
    .init("EFF_DATE", .null),
    .init("FIX_ID", .string()),
    .init("ICAO_REGION_CODE", .string(nullable: .blank)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("COUNTRY_CODE", .string(nullable: .blank)),
    .init("CHARTING_TYPE_DESC", .string(nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse FIX_BASE.csv first
    try await parseCSVFile(
      filename: "FIX_BASE.csv",
      requiredColumns: ["FIX_ID", "LAT_DECIMAL", "LONG_DECIMAL"]
    ) { row in
      let t = try self.baseTransformer.applyTo(row)

      // Parse position from decimal degrees - convert to arc-seconds for Location
      let latDecimal: Float? = try t[optional: "LAT_DECIMAL"]
      let lonDecimal: Float? = try t[optional: "LONG_DECIMAL"]

      let fixID: String = try t["FIX_ID"]
      guard
        let position = try self.makeLocation(
          latitude: latDecimal,
          longitude: lonDecimal,
          context: "fix \(fixID)"
        )
      else {
        throw ParserError.missingRequiredField(field: "position", recordType: "FIX_BASE")
      }

      // Note: CSV doesn't have stateName directly, but we can use stateCode
      let stateCode: String = try t[optional: "STATE_CODE"] ?? ""

      let fix = Fix(
        id: fixID,
        stateName: stateCode,  // Using state code as state name for CSV
        ICAORegion: try t[optional: "ICAO_REGION_CODE"] ?? "",
        position: position,
        category: .civil,  // CSV doesn't have category, default to civil
        navaidDescription: nil,  // Not in CSV
        radarDescription: nil,  // Not in CSV
        previousName: try t[optional: "FIX_ID_OLD"],
        chartingInfo: try t[optional: "CHARTING_REMARK"],
        isPublished: true,  // Assume published if in the file
        use: try t[optional: "FIX_USE_CODE"],
        NASId: nil,  // Not directly in CSV
        highARTCCCode: try t[optional: "ARTCC_ID_HIGH"],
        lowARTCCCode: try t[optional: "ARTCC_ID_LOW"],
        country: try t[optional: "COUNTRY_CODE"],
        isPitchPoint: try t[optional: "PITCH_FLAG"],
        isCatchPoint: try t[optional: "CATCH_FLAG"],
        isAssociatedWithSUA: try t[optional: "SUA_ATCAA_FLAG"]
      )

      let key = FixKey(fix: fix)
      self.fixes[key] = fix
    }

    // Parse FIX_NAV.csv for navaid makeups
    try await parseCSVFile(
      filename: "FIX_NAV.csv",
      requiredColumns: ["FIX_ID", "NAV_ID", "NAV_TYPE"]
    ) { row in
      let t = try self.navTransformer.applyTo(row)

      let navFixID: String = try t["FIX_ID"],
        stateCode: String = try t[optional: "STATE_CODE"] ?? "",
        key = FixKey(id: navFixID, stateName: stateCode)

      guard var fix = self.fixes[key] else {
        throw ParserError.unknownParentRecord(
          parentType: "Fix",
          parentID: navFixID,
          childType: "navaid makeup"
        )
      }

      let navId: String = try t["NAV_ID"]
      let navTypeStr: String = try t["NAV_TYPE"]
      let bearing: Float? = try t[optional: "BEARING"]
      let distanceNM: Float? = try t[optional: "DISTANCE"]

      // Map CSV nav types to NavaidTypeCode
      if let navaidType = mapCSVNavType(navTypeStr) {
        let makeup = Fix.NavaidMakeup(
          navaidId: navId,
          navaidType: navaidType,
          radialDeg: bearing.map { UInt($0) },
          distanceNM: distanceNM,
          rawDescription: "\(navId)*\(navTypeStr)*\(bearing ?? 0)/\(distanceNM ?? 0)"
        )
        fix.navaidMakeups.append(makeup)
        self.fixes[key] = fix
      }
    }

    // Parse FIX_CHRT.csv for chart types
    try await parseCSVFile(
      filename: "FIX_CHRT.csv",
      requiredColumns: ["FIX_ID"]
    ) { row in
      let t = try self.chartTransformer.applyTo(row)

      let chartFixID: String = try t["FIX_ID"],
        stateCode: String = try t[optional: "STATE_CODE"] ?? "",
        key = FixKey(id: chartFixID, stateName: stateCode)

      guard var fix = self.fixes[key] else {
        throw ParserError.unknownParentRecord(
          parentType: "Fix",
          parentID: chartFixID,
          childType: "chart type"
        )
      }

      if let chartType: String = try t[optional: "CHARTING_TYPE_DESC"] {
        fix.chartTypes.insert(chartType)
        self.fixes[key] = fix
      }
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(fixes: Array(fixes.values))
  }

  /// Creates a Location from optional lat/lon (decimal degrees), throwing if only one is present.
  /// Converts decimal degrees to arc-seconds for Location storage.
  private func makeLocation(
    latitude: Float?,
    longitude: Float?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        // Convert decimal degrees to arc-seconds (multiply by 3600)
        return Location(
          latitudeArcsec: lat * 3600,
          longitudeArcsec: lon * 3600,
          elevationFtMSL: nil
        )
      case (.none, .none):
        return nil
      default:
        throw ParserError.invalidLocation(
          latitude: latitude,
          longitude: longitude,
          context: context
        )
    }
  }
}

// MARK: - Helper functions

private func parseFixUse(_ string: String) throws -> Fix.Use {
  // CSV uses short codes like "WP" instead of "WAYPOINT"
  let trimmed = string.trimmingCharacters(in: .whitespaces)
  switch trimmed {
    case "CN", "CNF": return .computerNavigationFix
    case "MR", "MIL-REP-PT": return .militaryReportingPoint
    case "MW", "MIL-WAYPOINT", "MIL-WP": return .militaryWaypoint
    case "NRS", "NRS-WAYPOINT", "NRS-WP": return .NRSWaypoint
    case "RADAR": return .radar
    case "RP", "REP-PT": return .reportingPoint
    case "VFR", "VFR-WP": return .VFRWaypoint
    case "WP", "WAYPOINT": return .waypoint
    default:
      if let use = Fix.Use.for(trimmed) {
        return use
      }
      throw ParserError.unknownRecordEnumValue(trimmed)
  }
}

private func mapCSVNavType(_ csvType: String) -> Navaid.FacilityType? {
  // CSV uses different type codes than TXT format
  switch csvType.uppercased() {
    case "VORTAC": return .VORTAC
    case "TACAN": return .TACAN
    case "VOR/DME", "VORDME": return .VOR_DME
    case "VOR": return .VOR
    case "DME": return .DME
    case "NDB": return .NDB
    case "NDB/DME", "NDBDME": return .NDB_DME
    case "VOT": return .VOT
    case "LOC", "LOCALIZER": return .VOR  // Localizers mapped to VOR type for navaid makeup
    case "ILS": return .VOR
    default: return Navaid.FacilityType.for(csvType)
  }
}
