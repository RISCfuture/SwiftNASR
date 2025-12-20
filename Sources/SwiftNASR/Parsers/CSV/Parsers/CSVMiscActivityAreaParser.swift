import Foundation
import StreamingCSV

/// CSV Misc Activity Area Parser for parsing MAA_BASE.csv, MAA_CON.csv, MAA_RMK.csv, and MAA_SHP.csv
actor CSVMiscActivityAreaParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["MAA_BASE.csv", "MAA_CON.csv", "MAA_RMK.csv", "MAA_SHP.csv"]

  var areas = [String: MiscActivityArea]()

  // CSV field indices for MAA_BASE.csv (0-based)
  // EFF_DATE(0), MAA_ID(1), MAA_TYPE_NAME(2), NAV_ID(3), NAV_TYPE(4), NAV_RADIAL(5),
  // NAV_DISTANCE(6), STATE_CODE(7), CITY(8), LATITUDE(9), LONGITUDE(10), ARPT_IDS(11),
  // NEAREST_ARPT(12), NEAREST_ARPT_DIST(13), NEAREST_ARPT_DIR(14), MAA_NAME(15),
  // MAX_ALT(16), MIN_ALT(17), MAA_RADIUS(18), DESCRIPTION(19), MAA_USE(20),
  // CHECK_NOTAMS(21), TIME_OF_USE(22), USER_GROUP_NAME(23)
  private let baseFieldMapping: [Int] = [
    0,  //  0: EFF_DATE -> ignored
    1,  //  1: MAA_ID
    2,  //  2: MAA_TYPE_NAME
    3,  //  3: NAV_ID
    4,  //  4: NAV_TYPE
    5,  //  5: NAV_RADIAL
    6,  //  6: NAV_DISTANCE
    7,  //  7: STATE_CODE
    8,  //  8: CITY
    9,  //  9: LATITUDE (DMS format)
    10,  // 10: LONGITUDE (DMS format)
    11,  // 11: ARPT_IDS (associated airport identifiers)
    12,  // 12: NEAREST_ARPT
    13,  // 13: NEAREST_ARPT_DIST
    14,  // 14: NEAREST_ARPT_DIR
    15,  // 15: MAA_NAME
    16,  // 16: MAX_ALT
    17,  // 17: MIN_ALT
    18,  // 18: MAA_RADIUS
    19,  // 19: DESCRIPTION
    20,  // 20: MAA_USE
    21,  // 21: CHECK_NOTAMS
    22,  // 22: TIME_OF_USE
    23  // 23: USER_GROUP_NAME
  ]

  private let baseTransformer = CSVTransformer([
    .null,  //  0: EFF_DATE -> ignored
    .string(),  //  1: MAA_ID
    .string(nullable: .blank),  //  2: MAA_TYPE_NAME
    .string(nullable: .blank),  //  3: NAV_ID
    .string(nullable: .blank),  //  4: NAV_TYPE
    .float(nullable: .blank),  //  5: NAV_RADIAL
    .float(nullable: .blank),  //  6: NAV_DISTANCE
    .string(nullable: .blank),  //  7: STATE_CODE
    .string(nullable: .blank),  //  8: CITY
    .string(nullable: .blank),  //  9: LATITUDE (DMS format string)
    .string(nullable: .blank),  // 10: LONGITUDE (DMS format string)
    .string(nullable: .blank),  // 11: ARPT_IDS
    .string(nullable: .blank),  // 12: NEAREST_ARPT
    .float(nullable: .blank),  // 13: NEAREST_ARPT_DIST
    .string(nullable: .blank),  // 14: NEAREST_ARPT_DIR
    .string(nullable: .blank),  // 15: MAA_NAME
    .string(nullable: .blank),  // 16: MAX_ALT
    .string(nullable: .blank),  // 17: MIN_ALT
    .float(nullable: .blank),  // 18: MAA_RADIUS
    .string(nullable: .blank),  // 19: DESCRIPTION
    .string(nullable: .blank),  // 20: MAA_USE
    .string(nullable: .blank),  // 21: CHECK_NOTAMS
    .string(nullable: .blank),  // 22: TIME_OF_USE
    .string(nullable: .blank)  // 23: USER_GROUP_NAME
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse MAA_BASE.csv
    try await parseCSVFile(filename: "MAA_BASE.csv", expectedFieldCount: 24) { fields in
      guard fields.count >= 22 else { return }

      // Map CSV fields to transformer indices
      var mappedFields = [String](repeating: "", count: 24)
      for (transformerIndex, csvIndex) in self.baseFieldMapping.enumerated()
      where csvIndex < fields.count {
        mappedFields[transformerIndex] = fields[csvIndex]
      }

      let transformedValues = try self.baseTransformer.applyTo(
        mappedFields,
        indices: Array(0..<24)
      )

      let MAAId = transformedValues[1] as! String

      // Parse position from DMS strings
      let position = try self.makeLocationFromDMS(
        latitudeStr: transformedValues[9] as? String,
        longitudeStr: transformedValues[10] as? String,
        context: "MAA \(MAAId) position"
      )

      // Parse area type
      let areaType: MiscActivityArea.AreaType? = {
        guard let typeStr = transformedValues[2] as? String, !typeStr.isEmpty else { return nil }
        return MiscActivityArea.AreaType(rawValue: typeStr)
      }()

      // Parse altitudes (format like "5000AGL" or "4000MSL")
      let maxAltitude: Altitude? = {
        guard let altStr = transformedValues[16] as? String, !altStr.isEmpty else { return nil }
        return try? Altitude(parsing: altStr)
      }()

      let minAltitude: Altitude? = {
        guard let altStr = transformedValues[17] as? String, !altStr.isEmpty else { return nil }
        return try? Altitude(parsing: altStr)
      }()

      // Parse nearest airport direction
      let nearestDirection: Direction? = {
        guard let dirStr = transformedValues[14] as? String, !dirStr.isEmpty else { return nil }
        return Direction(rawValue: dirStr)
      }()

      // Parse times of use - single string in CSV
      let timesOfUse: [String] = {
        guard let timesStr = transformedValues[22] as? String, !timesStr.isEmpty else { return [] }
        return [timesStr]
      }()

      // Parse user groups - single string in CSV
      let userGroups: [String] = {
        guard let usersStr = transformedValues[23] as? String, !usersStr.isEmpty else { return [] }
        return [usersStr]
      }()

      // Parse check for NOTAMs - single string in CSV, may be comma-separated
      let checkForNOTAMs: [String] = {
        guard let notamsStr = transformedValues[21] as? String, !notamsStr.isEmpty else {
          return []
        }
        // If it contains commas, split; otherwise treat as single entry
        if notamsStr.contains(",") {
          return
            notamsStr
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        }
        return [notamsStr]
      }()

      let area = MiscActivityArea(
        MAAId: MAAId,
        areaType: areaType,
        areaName: transformedValues[15] as? String,
        stateCode: transformedValues[7] as? String,
        stateName: nil,  // CSV only has code, not name
        city: transformedValues[8] as? String,
        position: position,
        navaidIdentifier: transformedValues[3] as? String,
        navaidFacilityTypeCode: nil,  // Not in CSV format
        navaidFacilityType: transformedValues[4] as? String,
        navaidName: nil,  // Not in CSV format
        navaidAzimuthDeg: (transformedValues[5] as? Float).map { Double($0) },
        navaidDistanceNM: (transformedValues[6] as? Float).map { Double($0) },
        associatedAirportId: transformedValues[11] as? String,
        associatedAirportName: nil,  // CSV has ID, not name
        associatedAirportSiteNumber: nil,  // Not in CSV format
        nearestAirportId: transformedValues[12] as? String,
        nearestAirportDistanceNM: (transformedValues[13] as? Float).map { Double($0) },
        nearestAirportDirection: nearestDirection,
        maximumAltitude: maxAltitude,
        minimumAltitude: minAltitude,
        areaRadiusNM: (transformedValues[18] as? Float).map { Double($0) },
        isShownOnVFRChart: nil,  // Not in CSV format
        areaDescription: transformedValues[19] as? String,
        areaUse: transformedValues[20] as? String,
        polygonCoordinates: [],
        timesOfUse: timesOfUse,
        userGroups: userGroups,
        contactFacilities: [],
        checkForNOTAMs: checkForNOTAMs,
        remarks: []
      )

      self.areas[MAAId] = area
    }

    // Parse MAA_CON.csv for contact facilities
    // Columns: EFF_DATE(0), MAA_ID(1), FREQ_SEQ(2), FAC_ID(3), FAC_NAME(4),
    // COMMERCIAL_FREQ(5), COMMERCIAL_CHART_FLAG(6), MIL_FREQ(7), MIL_CHART_FLAG(8)
    try await parseCSVFile(filename: "MAA_CON.csv", expectedFieldCount: 9) { fields in
      guard fields.count >= 6 else { return }

      let MAAId = fields[1].trimmingCharacters(in: .whitespaces)
      guard !MAAId.isEmpty, self.areas[MAAId] != nil else { return }

      let facilityId = fields[3].trimmingCharacters(in: .whitespaces)
      let facilityName = fields[4].trimmingCharacters(in: .whitespaces)
      let commFreqStr = fields[5].trimmingCharacters(in: .whitespaces)
      let commChartFlag = fields.count > 6 ? fields[6].trimmingCharacters(in: .whitespaces) : ""

      // Optional military fields
      let milFreqStr = fields.count > 7 ? fields[7].trimmingCharacters(in: .whitespaces) : ""
      let milChartFlag = fields.count > 8 ? fields[8].trimmingCharacters(in: .whitespaces) : ""

      // Parse frequencies - CSV has them in MHz with decimal (e.g., "128.37")
      let commercialFrequencyKHz: UInt? = {
        guard let freq = Double(commFreqStr) else { return nil }
        return UInt(freq * 1000)
      }()

      let militaryFrequencyKHz: UInt? = {
        guard !milFreqStr.isEmpty, let freq = Double(milFreqStr) else { return nil }
        return UInt(freq * 1000)
      }()

      let facility = MiscActivityArea.ContactFacility(
        facilityId: facilityId.isEmpty ? nil : facilityId,
        facilityName: facilityName.isEmpty ? nil : facilityName,
        commercialFrequencyKHz: commercialFrequencyKHz,
        showCommercialOnChart: commChartFlag == "Y",
        militaryFrequencyKHz: militaryFrequencyKHz,
        showMilitaryOnChart: milChartFlag == "Y"
      )

      self.areas[MAAId]?.contactFacilities.append(facility)
    }

    // Parse MAA_RMK.csv for remarks
    // Columns: EFF_DATE(0), MAA_ID(1), TAB_NAME(2), REF_COL_NAME(3), REF_COL_SEQ_NO(4), REMARK(5)
    try await parseCSVFile(filename: "MAA_RMK.csv", expectedFieldCount: 6) { fields in
      guard fields.count >= 6 else { return }

      let MAAId = fields[1].trimmingCharacters(in: .whitespaces)
      guard !MAAId.isEmpty, self.areas[MAAId] != nil else { return }

      let remark = fields[5].trimmingCharacters(in: .whitespaces)
      if !remark.isEmpty {
        self.areas[MAAId]?.remarks.append(remark)
      }
    }

    // Parse MAA_SHP.csv for polygon coordinates
    // Columns: EFF_DATE(0), MAA_ID(1), POINT_SEQ(2), LATITUDE(3), LONGITUDE(4)
    try await parseCSVFile(filename: "MAA_SHP.csv", expectedFieldCount: 5) { fields in
      guard fields.count >= 5 else { return }

      let MAAId = fields[1].trimmingCharacters(in: .whitespaces)
      guard !MAAId.isEmpty, self.areas[MAAId] != nil else { return }

      let latStr = fields[3].trimmingCharacters(in: .whitespaces)
      let lonStr = fields[4].trimmingCharacters(in: .whitespaces)

      let position = try self.makeLocationFromDMS(
        latitudeStr: latStr.isEmpty ? nil : latStr,
        longitudeStr: lonStr.isEmpty ? nil : lonStr,
        context: "MAA \(MAAId) polygon coordinate"
      )

      let coordinate = MiscActivityArea.PolygonCoordinate(position: position)
      self.areas[MAAId]?.polygonCoordinates.append(coordinate)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(miscActivityAreas: Array(areas.values))
  }

  // MARK: - Private Helpers

  /// Creates a Location from DMS (degrees-minutes-seconds) format strings.
  /// Format: "DD-MM-SS.SSSSH" where H is N/S for latitude or E/W for longitude.
  private func makeLocationFromDMS(
    latitudeStr: String?,
    longitudeStr: String?,
    context: String
  ) throws -> Location? {
    switch (latitudeStr, longitudeStr) {
      case let (.some(latStr), .some(lonStr)):
        guard let lat = parseLatitude(latStr),
          let lon = parseLongitude(lonStr)
        else {
          throw ParserError.invalidLocation(
            latitude: nil,
            longitude: nil,
            context: context
          )
        }
        // Convert decimal degrees to arc-seconds (multiply by 3600)
        return Location(latitudeArcsec: Float(lat * 3600), longitudeArcsec: Float(lon * 3600))
      case (.none, .none):
        return nil
      default:
        throw ParserError.invalidLocation(
          latitude: nil,
          longitude: nil,
          context: context
        )
    }
  }

  /// Parse latitude string (DD-MM-SS.SSSSH format)
  private func parseLatitude(_ str: String) -> Double? {
    guard !str.isEmpty else { return nil }

    let isNorth = str.hasSuffix("N")
    let isSouth = str.hasSuffix("S")
    var working = str
    if isNorth || isSouth {
      working = String(str.dropLast())
    }

    // Try DD-MM-SS.SSSSH format first
    if working.contains("-") {
      let parts = working.split(separator: "-")
      guard parts.count >= 3 else { return nil }

      guard let degrees = Double(parts[0]),
        let minutes = Double(parts[1]),
        let seconds = Double(parts[2])
      else { return nil }

      var lat = degrees + (minutes / 60.0) + (seconds / 3600.0)
      if isSouth { lat = -lat }
      return lat
    }

    // Try packed format DDMMSS.SSSS
    guard working.count >= 6 else { return nil }
    guard let degrees = Double(working.prefix(2)),
      let minutes = Double(working.dropFirst(2).prefix(2)),
      let seconds = Double(working.dropFirst(4))
    else { return nil }

    var lat = degrees + (minutes / 60.0) + (seconds / 3600.0)
    if isSouth { lat = -lat }
    return lat
  }

  /// Parse longitude string (DDD-MM-SS.SSSSH format)
  private func parseLongitude(_ str: String) -> Double? {
    guard !str.isEmpty else { return nil }

    let isWest = str.hasSuffix("W")
    let isEast = str.hasSuffix("E")
    var working = str
    if isWest || isEast {
      working = String(str.dropLast())
    }

    // Try DDD-MM-SS.SSSSH format first
    if working.contains("-") {
      let parts = working.split(separator: "-")
      guard parts.count >= 3 else { return nil }

      guard let degrees = Double(parts[0]),
        let minutes = Double(parts[1]),
        let seconds = Double(parts[2])
      else { return nil }

      var lon = degrees + (minutes / 60.0) + (seconds / 3600.0)
      if isWest { lon = -lon }
      return lon
    }

    // Try packed format DDDMMSS.SSSS
    guard working.count >= 7 else { return nil }
    guard let degrees = Double(working.prefix(3)),
      let minutes = Double(working.dropFirst(3).prefix(2)),
      let seconds = Double(working.dropFirst(5))
    else { return nil }

    var lon = degrees + (minutes / 60.0) + (seconds / 3600.0)
    if isWest { lon = -lon }
    return lon
  }
}
