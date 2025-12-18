import Foundation
import StreamingCSV
import ZIPFoundation

/// CSV Fix Parser for parsing FIX_BASE.csv, FIX_NAV.csv, and FIX_CHRT.csv
class CSVFixParser: CSVParser {
  var csvDirectory = URL(fileURLWithPath: "/")
  var fixes = [FixKey: Fix]()

  // CSV field mapping for FIX_BASE.csv (0-based indices)
  // Headers: EFF_DATE,FIX_ID,ICAO_REGION_CODE,STATE_CODE,COUNTRY_CODE,LAT_DEG,LAT_MIN,LAT_SEC,LAT_HEMIS,LAT_DECIMAL,
  //          LONG_DEG,LONG_MIN,LONG_SEC,LONG_HEMIS,LONG_DECIMAL,FIX_ID_OLD,CHARTING_REMARK,FIX_USE_CODE,ARTCC_ID_HIGH,
  //          ARTCC_ID_LOW,PITCH_FLAG,CATCH_FLAG,SUA_ATCAA_FLAG,MIN_RECEP_ALT,COMPULSORY,CHARTS
  private let baseFieldMapping: [Int] = [
    0,  //  0: EFF_DATE
    1,  //  1: FIX_ID
    2,  //  2: ICAO_REGION_CODE
    3,  //  3: STATE_CODE
    4,  //  4: COUNTRY_CODE
    9,  //  5: LAT_DECIMAL
    14,  //  6: LONG_DECIMAL
    15,  //  7: FIX_ID_OLD
    16,  //  8: CHARTING_REMARK
    17,  //  9: FIX_USE_CODE
    18,  // 10: ARTCC_ID_HIGH
    19,  // 11: ARTCC_ID_LOW
    20,  // 12: PITCH_FLAG
    21,  // 13: CATCH_FLAG
    22  // 14: SUA_ATCAA_FLAG
  ]

  private let baseTransformer = CSVTransformer([
    .null,  //  0: effective date
    .string(),  //  1: fix ID
    .string(nullable: .blank),  //  2: ICAO region code
    .string(nullable: .blank),  //  3: state code
    .string(nullable: .blank),  //  4: country code
    .float(nullable: .blank),  //  5: lat decimal
    .float(nullable: .blank),  //  6: lon decimal
    .string(nullable: .blank),  //  7: previous name (FIX_ID_OLD)
    .string(nullable: .blank),  //  8: charting remark
    .generic({ try parseFixUse($0) }, nullable: .blank),  //  9: fix use code
    .string(nullable: .blank),  // 10: high ARTCC code
    .string(nullable: .blank),  // 11: low ARTCC code
    .boolean(),  // 12: pitch flag
    .boolean(),  // 13: catch flag
    .boolean()  // 14: SUA/ATCAA flag
  ])

  // FIX_NAV.csv field mapping
  // Headers: EFF_DATE,FIX_ID,ICAO_REGION_CODE,STATE_CODE,COUNTRY_CODE,NAV_ID,NAV_TYPE,BEARING,DISTANCE
  private let navFieldMapping: [Int] = [
    0,  // 0: EFF_DATE
    1,  // 1: FIX_ID
    2,  // 2: ICAO_REGION_CODE
    3,  // 3: STATE_CODE
    4,  // 4: COUNTRY_CODE
    5,  // 5: NAV_ID
    6,  // 6: NAV_TYPE
    7,  // 7: BEARING
    8  // 8: DISTANCE
  ]

  private let navTransformer = CSVTransformer([
    .null,  // 0: effective date
    .string(),  // 1: fix ID
    .string(nullable: .blank),  // 2: ICAO region code
    .string(nullable: .blank),  // 3: state code
    .string(nullable: .blank),  // 4: country code
    .string(),  // 5: nav ID
    .string(),  // 6: nav type
    .float(nullable: .blank),  // 7: bearing
    .float(nullable: .blank)  // 8: distance
  ])

  // FIX_CHRT.csv field mapping
  // Headers: EFF_DATE,FIX_ID,ICAO_REGION_CODE,STATE_CODE,COUNTRY_CODE,CHARTING_TYPE_DESC
  private let chartFieldMapping: [Int] = [
    0,  // 0: EFF_DATE
    1,  // 1: FIX_ID
    2,  // 2: ICAO_REGION_CODE
    3,  // 3: STATE_CODE
    4,  // 4: COUNTRY_CODE
    5  // 5: CHARTING_TYPE_DESC
  ]

  private let chartTransformer = CSVTransformer([
    .null,  // 0: effective date
    .string(),  // 1: fix ID
    .string(nullable: .blank),  // 2: ICAO region code
    .string(nullable: .blank),  // 3: state code
    .string(nullable: .blank),  // 4: country code
    .string(nullable: .blank)  // 5: chart type
  ])

  func prepare(distribution: Distribution) throws {
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
    // Parse FIX_BASE.csv first
    try await parseCSVFile(filename: "FIX_BASE.csv", expectedFieldCount: 26) { fields in
      guard fields.count >= 15 else {
        throw ParserError.truncatedRecord(
          recordType: "FIX_BASE",
          expectedMinLength: 15,
          actualLength: fields.count
        )
      }

      var mappedFields = [String](repeating: "", count: 15)
      for (transformerIndex, csvIndex) in self.baseFieldMapping.enumerated()
      where csvIndex < fields.count {
        mappedFields[transformerIndex] = fields[csvIndex]
      }

      let transformedValues = try self.baseTransformer.applyTo(
        mappedFields,
        indices: Array(0..<15)
      )

      // Parse position from decimal degrees - convert to arc-seconds for Location
      let latDecimal = transformedValues[5] as? Float
      let lonDecimal = transformedValues[6] as? Float

      let fixID = transformedValues[1] as! String
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
      // The TXT format uses full state name, so we'll need to handle this
      let stateCode = transformedValues[3] as? String ?? ""

      let fix = Fix(
        id: fixID,
        stateName: stateCode,  // Using state code as state name for CSV
        ICAORegion: transformedValues[2] as? String ?? "",
        position: position,
        category: .civil,  // CSV doesn't have category, default to civil
        navaidDescription: nil,  // Not in CSV
        radarDescription: nil,  // Not in CSV
        previousName: transformedValues[7] as? String,
        chartingInfo: transformedValues[8] as? String,
        isPublished: true,  // Assume published if in the file
        use: transformedValues[9] as? Fix.Use,
        NASId: nil,  // Not directly in CSV
        highARTCCCode: transformedValues[10] as? String,
        lowARTCCCode: transformedValues[11] as? String,
        country: transformedValues[4] as? String,
        isPitchPoint: transformedValues[12] as? Bool,
        isCatchPoint: transformedValues[13] as? Bool,
        isAssociatedWithSUA: transformedValues[14] as? Bool
      )

      let key = FixKey(fix: fix)
      self.fixes[key] = fix
    }

    // Parse FIX_NAV.csv for navaid makeups
    try await parseCSVFile(filename: "FIX_NAV.csv", expectedFieldCount: 9) { fields in
      guard fields.count >= 9 else {
        throw ParserError.truncatedRecord(
          recordType: "FIX_NAV",
          expectedMinLength: 9,
          actualLength: fields.count
        )
      }

      var mappedFields = [String](repeating: "", count: 9)
      for (transformerIndex, csvIndex) in self.navFieldMapping.enumerated()
      where csvIndex < fields.count {
        mappedFields[transformerIndex] = fields[csvIndex]
      }

      let transformedValues = try self.navTransformer.applyTo(
        mappedFields,
        indices: Array(0..<9)
      )

      let navFixID = transformedValues[1] as! String
      let stateCode = transformedValues[3] as? String ?? ""
      let key = FixKey(values: [nil, navFixID, stateCode])

      guard var fix = self.fixes[key] else {
        throw ParserError.unknownParentRecord(
          parentType: "Fix",
          parentID: navFixID,
          childType: "navaid makeup"
        )
      }

      let navId = transformedValues[5] as! String
      let navTypeStr = transformedValues[6] as! String
      let bearing = transformedValues[7] as? Float
      let distanceNM = transformedValues[8] as? Float

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
    try await parseCSVFile(filename: "FIX_CHRT.csv", expectedFieldCount: 6) { fields in
      guard fields.count >= 6 else {
        throw ParserError.truncatedRecord(
          recordType: "FIX_CHRT",
          expectedMinLength: 6,
          actualLength: fields.count
        )
      }

      var mappedFields = [String](repeating: "", count: 6)
      for (transformerIndex, csvIndex) in self.chartFieldMapping.enumerated()
      where csvIndex < fields.count {
        mappedFields[transformerIndex] = fields[csvIndex]
      }

      let transformedValues = try self.chartTransformer.applyTo(
        mappedFields,
        indices: Array(0..<6)
      )

      let chartFixID = transformedValues[1] as! String
      let stateCode = transformedValues[3] as? String ?? ""
      let key = FixKey(values: [nil, chartFixID, stateCode])

      guard var fix = self.fixes[key] else {
        throw ParserError.unknownParentRecord(
          parentType: "Fix",
          parentID: chartFixID,
          childType: "chart type"
        )
      }

      if let chartType = transformedValues[5] as? String {
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
    case "VOR/DME", "VORDME": return .VORDME
    case "VOR": return .VOR
    case "DME": return .DME
    case "NDB": return .NDB
    case "NDB/DME", "NDBDME": return .NDBDME
    case "VOT": return .VOT
    case "LOC", "LOCALIZER": return .VOR  // Localizers mapped to VOR type for navaid makeup
    case "ILS": return .VOR
    default: return Navaid.FacilityType.for(csvType)
  }
}
