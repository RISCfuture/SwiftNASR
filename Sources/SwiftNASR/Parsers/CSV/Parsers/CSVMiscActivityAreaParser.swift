import Foundation
import StreamingCSV

/// CSV Misc Activity Area Parser for parsing MAA_BASE.csv, MAA_CON.csv, MAA_RMK.csv, and MAA_SHP.csv
actor CSVMiscActivityAreaParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["MAA_BASE.csv", "MAA_CON.csv", "MAA_RMK.csv", "MAA_SHP.csv"]

  var areas = [String: MiscActivityArea]()

  private let baseTransformer = CSVTransformer([
    .init("MAA_ID", .string()),
    .init("MAA_TYPE_NAME", .string(nullable: .blank)),
    .init("NAV_ID", .string(nullable: .blank)),
    .init("NAV_TYPE", .string(nullable: .blank)),
    .init("NAV_RADIAL", .float(nullable: .blank)),
    .init("NAV_DISTANCE", .float(nullable: .blank)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("CITY", .string(nullable: .blank)),
    .init("LATITUDE", .string(nullable: .blank)),
    .init("LONGITUDE", .string(nullable: .blank)),
    .init("ARPT_IDS", .string(nullable: .blank)),
    .init("NEAREST_ARPT", .string(nullable: .blank)),
    .init("NEAREST_ARPT_DIST", .float(nullable: .blank)),
    .init("NEAREST_ARPT_DIR", .string(nullable: .blank)),
    .init("MAA_NAME", .string(nullable: .blank)),
    .init("MAX_ALT", .string(nullable: .blank)),
    .init("MIN_ALT", .string(nullable: .blank)),
    .init("MAA_RADIUS", .float(nullable: .blank)),
    .init("DESCRIPTION", .string(nullable: .blank)),
    .init("MAA_USE", .string(nullable: .blank)),
    .init("CHECK_NOTAMS", .string(nullable: .blank)),
    .init("TIME_OF_USE", .string(nullable: .blank)),
    .init("USER_GROUP_NAME", .string(nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse MAA_BASE.csv
    try await parseCSVFile(
      filename: "MAA_BASE.csv",
      requiredColumns: ["MAA_ID"]
    ) { row in
      let t = try self.baseTransformer.applyTo(row)

      let MAAId: String = try t["MAA_ID"]

      // Parse position from DMS strings
      let latStr: String? = try t[optional: "LATITUDE"]
      let lonStr: String? = try t[optional: "LONGITUDE"]
      let position = try self.makeLocationFromDMS(
        latitudeStr: latStr,
        longitudeStr: lonStr,
        context: "MAA \(MAAId) position"
      )

      // Parse area type
      let areaType: MiscActivityArea.AreaType? = {
        guard let typeStr: String = try? t[optional: "MAA_TYPE_NAME"], !typeStr.isEmpty else {
          return nil
        }
        return MiscActivityArea.AreaType(rawValue: typeStr)
      }()

      // Parse altitudes (format like "5000AGL" or "4000MSL")
      let maxAltitude: Altitude? = {
        guard let altStr: String = try? t[optional: "MAX_ALT"], !altStr.isEmpty else { return nil }
        return try? Altitude(parsing: altStr)
      }()

      let minAltitude: Altitude? = {
        guard let altStr: String = try? t[optional: "MIN_ALT"], !altStr.isEmpty else { return nil }
        return try? Altitude(parsing: altStr)
      }()

      // Parse nearest airport direction
      let nearestDirection: Direction? = {
        guard let dirStr: String = try? t[optional: "NEAREST_ARPT_DIR"], !dirStr.isEmpty else {
          return nil
        }
        return Direction(rawValue: dirStr)
      }()

      // Parse times of use - single string in CSV
      let timesOfUse: [String] = {
        guard let timesStr: String = try? t[optional: "TIME_OF_USE"], !timesStr.isEmpty else {
          return []
        }
        return [timesStr]
      }()

      // Parse user groups - single string in CSV
      let userGroups: [String] = {
        guard let usersStr: String = try? t[optional: "USER_GROUP_NAME"], !usersStr.isEmpty else {
          return []
        }
        return [usersStr]
      }()

      // Parse check for NOTAMs - single string in CSV, may be comma-separated
      let checkForNOTAMs: [String] = {
        guard let notamsStr: String = try? t[optional: "CHECK_NOTAMS"], !notamsStr.isEmpty else {
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

      let navRadial: Float? = try t[optional: "NAV_RADIAL"]
      let navDistance: Float? = try t[optional: "NAV_DISTANCE"]
      let nearestArptDist: Float? = try t[optional: "NEAREST_ARPT_DIST"]
      let radius: Float? = try t[optional: "MAA_RADIUS"]

      let area = MiscActivityArea(
        MAAId: MAAId,
        areaType: areaType,
        areaName: try t[optional: "MAA_NAME"],
        stateCode: try t[optional: "STATE_CODE"],
        stateName: nil,  // CSV only has code, not name
        city: try t[optional: "CITY"],
        position: position,
        navaidIdentifier: try t[optional: "NAV_ID"],
        navaidFacilityTypeCode: nil,  // Not in CSV format
        navaidFacilityType: try t[optional: "NAV_TYPE"],
        navaidName: nil,  // Not in CSV format
        navaidAzimuthDeg: navRadial.map { Double($0) },
        navaidDistanceNM: navDistance.map { Double($0) },
        associatedAirportId: try t[optional: "ARPT_IDS"],
        associatedAirportName: nil,  // CSV has ID, not name
        associatedAirportSiteNumber: nil,  // Not in CSV format
        nearestAirportId: try t[optional: "NEAREST_ARPT"],
        nearestAirportDistanceNM: nearestArptDist.map { Double($0) },
        nearestAirportDirection: nearestDirection,
        maximumAltitude: maxAltitude,
        minimumAltitude: minAltitude,
        areaRadiusNM: radius.map { Double($0) },
        isShownOnVFRChart: nil,  // Not in CSV format
        areaDescription: try t[optional: "DESCRIPTION"],
        areaUse: try t[optional: "MAA_USE"],
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
    try await parseCSVFile(
      filename: "MAA_CON.csv",
      requiredColumns: ["MAA_ID"]
    ) { row in
      let MAAId = try row["MAA_ID"]
      guard !MAAId.isEmpty, self.areas[MAAId] != nil else { return }

      let facilityId = try row.optional("FAC_ID")
      let facilityName = try row.optional("FAC_NAME")
      let commFreqStr = try row.optional("COMMERCIAL_FREQ") ?? ""
      let commChartFlag = try row.optional("COMMERCIAL_CHART_FLAG") ?? ""

      // Optional military fields
      let milFreqStr = try row.optional("MIL_FREQ") ?? ""
      let milChartFlag = try row.optional("MIL_CHART_FLAG") ?? ""

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
        facilityId: facilityId,
        facilityName: facilityName,
        commercialFrequencyKHz: commercialFrequencyKHz,
        showCommercialOnChart: try ParserHelpers.parseYNFlagRequired(
          commChartFlag,
          fieldName: "showCommercialOnChart"
        ),
        militaryFrequencyKHz: militaryFrequencyKHz,
        showMilitaryOnChart: try ParserHelpers.parseYNFlagRequired(
          milChartFlag,
          fieldName: "showMilitaryOnChart"
        )
      )

      self.areas[MAAId]?.contactFacilities.append(facility)
    }

    // Parse MAA_RMK.csv for remarks
    try await parseCSVFile(
      filename: "MAA_RMK.csv",
      requiredColumns: ["MAA_ID", "REMARK"]
    ) { row in
      let MAAId = try row["MAA_ID"]
      guard !MAAId.isEmpty, self.areas[MAAId] != nil else { return }

      let remark = try row["REMARK"]
      if !remark.isEmpty {
        self.areas[MAAId]?.remarks.append(remark)
      }
    }

    // Parse MAA_SHP.csv for polygon coordinates
    try await parseCSVFile(
      filename: "MAA_SHP.csv",
      requiredColumns: ["MAA_ID", "LATITUDE", "LONGITUDE"]
    ) { row in
      let MAAId = try row["MAA_ID"]
      guard !MAAId.isEmpty, self.areas[MAAId] != nil else { return }

      let latStr = try row.optional("LATITUDE")
      let lonStr = try row.optional("LONGITUDE")

      let position = try self.makeLocationFromDMS(
        latitudeStr: latStr,
        longitudeStr: lonStr,
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
