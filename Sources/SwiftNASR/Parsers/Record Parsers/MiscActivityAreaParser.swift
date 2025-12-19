import Foundation

/// Parser for MAA (Miscellaneous Activity Area) files.
///
/// These files contain information about aerobatic practice areas, glider areas,
/// hang glider areas, space launch areas, ultralight areas, and unmanned aircraft areas.
/// Records are 919 characters fixed-width with MAA1 (base), MAA2 (polygon coordinates),
/// MAA3 (times of use), MAA4 (user groups), MAA5 (contact facilities),
/// MAA6 (check for NOTAMs), and MAA7 (remarks).
actor FixedWidthMiscActivityAreaParser: LayoutDataParser {
  static let type = RecordType.miscActivityAreas

  var formats = [NASRTable]()
  var areas = [String: MiscActivityArea]()

  func parse(data: Data) throws {
    guard let line = String(data: data, encoding: .isoLatin1) else {
      throw ParserError.badData("Invalid ISO-Latin1 encoding in MAA record")
    }
    guard line.count >= 10 else {
      throw ParserError.truncatedRecord(
        recordType: "MAA",
        expectedMinLength: 10,
        actualLength: line.count
      )
    }

    let recordType = String(line.prefix(4))
    let MAAId = String(line.substring(4, 6)).trimmingCharacters(in: .whitespaces)

    guard !MAAId.isEmpty else {
      throw ParserError.missingRequiredField(field: "MAAId", recordType: "MAA")
    }

    switch recordType {
      case "MAA1":
        try parseBaseRecord(line, MAAId: MAAId)
      case "MAA2":
        try parsePolygonCoordinate(line, MAAId: MAAId)
      case "MAA3":
        try parseTimesOfUse(line, MAAId: MAAId)
      case "MAA4":
        try parseUserGroup(line, MAAId: MAAId)
      case "MAA5":
        try parseContactFacility(line, MAAId: MAAId)
      case "MAA6":
        try parseCheckForNOTAMs(line, MAAId: MAAId)
      case "MAA7":
        try parseRemarks(line, MAAId: MAAId)
      default:
        break
    }
  }

  private func parseBaseRecord(_ line: String, MAAId: String) throws {
    // MAA1 record format (919 chars):
    // Position 1-4: Record type "MAA1"
    // Position 5-10: MAA ID (6)
    // Position 11-35: MAA Type (25, right-justified)
    // Position 36-39: Navaid identifier (4)
    // Position 40-41: Navaid facility type code (2)
    // Position 42-66: Navaid facility type description (25)
    // Position 67-72: Azimuth from navaid (6)
    // Position 73-78: Distance from navaid (6)
    // Position 79-108: Navaid name (30)
    // Position 109-110: State abbreviation (2)
    // Position 111-140: State name (30)
    // Position 141-170: City name (30)
    // Position 171-184: Latitude formatted (14)
    // Position 185-196: Latitude seconds (12)
    // Position 197-211: Longitude formatted (15)
    // Position 212-223: Longitude seconds (12)
    // Position 224-227: Associated airport ID (4)
    // Position 228-277: Associated airport name (50)
    // Position 278-288: Associated airport site number (11)
    // Position 289-292: Nearest airport ID (4)
    // Position 293-298: Nearest airport distance (6)
    // Position 299-300: Nearest airport direction (2)
    // Position 301-420: Area name (120)
    // Position 421-428: Maximum altitude (8)
    // Position 429-436: Minimum altitude (8)
    // Position 437-441: Area radius (5, right-justified)
    // Position 442-444: Show on VFR chart (3)
    // Position 445-894: Area description (450)
    // Position 895-902: Area use (8)
    // Position 903-919: Blanks (17)

    let areaTypeStr = String(line.substring(10, 25)).trimmingCharacters(in: .whitespaces)
    let navaidIdent = String(line.substring(35, 4)).trimmingCharacters(in: .whitespaces)
    let navaidTypeCode = String(line.substring(39, 2)).trimmingCharacters(in: .whitespaces)
    let navaidTypeDesc = String(line.substring(41, 25)).trimmingCharacters(in: .whitespaces)
    let azimuthStr = String(line.substring(66, 6)).trimmingCharacters(in: .whitespaces)
    let distanceStr = String(line.substring(72, 6)).trimmingCharacters(in: .whitespaces)
    let navaidName = String(line.substring(78, 30)).trimmingCharacters(in: .whitespaces)
    let stateAbbr = String(line.substring(108, 2)).trimmingCharacters(in: .whitespaces)
    let stateName = String(line.substring(110, 30)).trimmingCharacters(in: .whitespaces)
    let city = String(line.substring(140, 30)).trimmingCharacters(in: .whitespaces)
    let latFormatted = String(line.substring(170, 14)).trimmingCharacters(in: .whitespaces)
    let lonFormatted = String(line.substring(196, 15)).trimmingCharacters(in: .whitespaces)
    let assocAirportID = String(line.substring(223, 4)).trimmingCharacters(in: .whitespaces)
    let assocAirportName = String(line.substring(227, 50)).trimmingCharacters(in: .whitespaces)
    let assocAirportSite = String(line.substring(277, 11)).trimmingCharacters(in: .whitespaces)
    let nearestAirportID = String(line.substring(288, 4)).trimmingCharacters(in: .whitespaces)
    let nearestDistStr = String(line.substring(292, 6)).trimmingCharacters(in: .whitespaces)
    let nearestDir = String(line.substring(298, 2)).trimmingCharacters(in: .whitespaces)
    let areaName = String(line.substring(300, 120)).trimmingCharacters(in: .whitespaces)
    let maxAlt = String(line.substring(420, 8)).trimmingCharacters(in: .whitespaces)
    let minAlt = String(line.substring(428, 8)).trimmingCharacters(in: .whitespaces)
    let radiusStr = String(line.substring(436, 5)).trimmingCharacters(in: .whitespaces)
    let showVFRStr = String(line.substring(441, 3)).trimmingCharacters(in: .whitespaces)
    let areaDesc = String(line.substring(444, 450)).trimmingCharacters(in: .whitespaces)
    let areaUse = String(line.substring(894, 8)).trimmingCharacters(in: .whitespaces)

    let lat = parseLatitude(latFormatted)
    let lon = parseLongitude(lonFormatted)
    let position = try makeLocation(
      latitude: lat,
      longitude: lon,
      context: "MAA \(MAAId) position"
    )

    let area = MiscActivityArea(
      MAAId: MAAId,
      areaType: MiscActivityArea.AreaType(rawValue: areaTypeStr),
      areaName: areaName.isEmpty ? nil : areaName,
      stateCode: stateAbbr.isEmpty ? nil : stateAbbr,
      stateName: stateName.isEmpty ? nil : stateName,
      city: city.isEmpty ? nil : city,
      position: position,
      navaidIdentifier: navaidIdent.isEmpty ? nil : navaidIdent,
      navaidFacilityTypeCode: navaidTypeCode.isEmpty ? nil : navaidTypeCode,
      navaidFacilityType: navaidTypeDesc.isEmpty ? nil : navaidTypeDesc,
      navaidName: navaidName.isEmpty ? nil : navaidName,
      navaidAzimuthDeg: Double(azimuthStr),
      navaidDistanceNM: Double(distanceStr),
      associatedAirportId: assocAirportID.isEmpty ? nil : assocAirportID,
      associatedAirportName: assocAirportName.isEmpty ? nil : assocAirportName,
      associatedAirportSiteNumber: assocAirportSite.isEmpty ? nil : assocAirportSite,
      nearestAirportId: nearestAirportID.isEmpty ? nil : nearestAirportID,
      nearestAirportDistanceNM: Double(nearestDistStr),
      nearestAirportDirection: Direction(rawValue: nearestDir),
      maximumAltitude: maxAlt.isEmpty ? nil : try Altitude(parsing: maxAlt),
      minimumAltitude: minAlt.isEmpty ? nil : try Altitude(parsing: minAlt),
      areaRadiusNM: Double(radiusStr),
      isShownOnVFRChart: parseYesNo(showVFRStr),
      areaDescription: areaDesc.isEmpty ? nil : areaDesc,
      areaUse: areaUse.isEmpty ? nil : areaUse,
      polygonCoordinates: [],
      timesOfUse: [],
      userGroups: [],
      contactFacilities: [],
      checkForNOTAMs: [],
      remarks: []
    )

    areas[MAAId] = area
  }

  private func parsePolygonCoordinate(_ line: String, MAAId: String) throws {
    // MAA2 record format:
    // Position 1-4: Record type "MAA2"
    // Position 5-10: MAA ID (6)
    // Position 11-24: Latitude formatted (14)
    // Position 25-36: Latitude seconds (12)
    // Position 37-51: Longitude formatted (15)
    // Position 52-63: Longitude seconds (12)
    guard line.count >= 63 else {
      throw ParserError.truncatedRecord(
        recordType: "MAA2",
        expectedMinLength: 63,
        actualLength: line.count
      )
    }
    guard areas[MAAId] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "MiscActivityArea",
        parentID: MAAId,
        childType: "polygon coordinate"
      )
    }

    let latFormatted = String(line.substring(10, 14)).trimmingCharacters(in: .whitespaces)
    let lonFormatted = String(line.substring(36, 15)).trimmingCharacters(in: .whitespaces)

    let polyLat = parseLatitude(latFormatted)
    let polyLon = parseLongitude(lonFormatted)
    let polyPosition = try makeLocation(
      latitude: polyLat,
      longitude: polyLon,
      context: "MAA \(MAAId) polygon coordinate"
    )

    let coordinate = MiscActivityArea.PolygonCoordinate(
      position: polyPosition
    )

    areas[MAAId]?.polygonCoordinates.append(coordinate)
  }

  private func parseTimesOfUse(_ line: String, MAAId: String) throws {
    // MAA3 record format:
    // Position 1-4: Record type "MAA3"
    // Position 5-10: MAA ID (6)
    // Position 11-85: Times of use description (75)
    guard line.count >= 85 else {
      throw ParserError.truncatedRecord(
        recordType: "MAA3",
        expectedMinLength: 85,
        actualLength: line.count
      )
    }
    guard areas[MAAId] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "MiscActivityArea",
        parentID: MAAId,
        childType: "times of use"
      )
    }
    let text = String(line.substring(10, 75)).trimmingCharacters(in: .whitespaces)
    if !text.isEmpty {
      areas[MAAId]?.timesOfUse.append(text)
    }
  }

  private func parseUserGroup(_ line: String, MAAId: String) throws {
    // MAA4 record format:
    // Position 1-4: Record type "MAA4"
    // Position 5-10: MAA ID (6)
    // Position 11-85: User group name (75)
    guard line.count >= 85 else {
      throw ParserError.truncatedRecord(
        recordType: "MAA4",
        expectedMinLength: 85,
        actualLength: line.count
      )
    }
    guard areas[MAAId] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "MiscActivityArea",
        parentID: MAAId,
        childType: "user group"
      )
    }
    let text = String(line.substring(10, 75)).trimmingCharacters(in: .whitespaces)
    if !text.isEmpty {
      areas[MAAId]?.userGroups.append(text)
    }
  }

  private func parseContactFacility(_ line: String, MAAId: String) throws {
    // MAA5 record format:
    // Position 1-4: Record type "MAA5"
    // Position 5-10: MAA ID (6)
    // Position 11-14: Contact facility ID (4)
    // Position 15-62: Contact facility name (48)
    // Position 63-69: Commercial frequency (7, right-justified)
    // Position 70: Commercial chart flag (1)
    // Position 71-77: Military frequency (7, right-justified)
    // Position 78: Military chart flag (1)
    guard line.count >= 78 else {
      throw ParserError.truncatedRecord(
        recordType: "MAA5",
        expectedMinLength: 78,
        actualLength: line.count
      )
    }
    guard areas[MAAId] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "MiscActivityArea",
        parentID: MAAId,
        childType: "contact facility"
      )
    }

    let facilityID = String(line.substring(10, 4)).trimmingCharacters(in: .whitespaces)
    let facilityName = String(line.substring(14, 48)).trimmingCharacters(in: .whitespaces)
    let commFreqStr = String(line.substring(62, 7)).trimmingCharacters(in: .whitespaces)
    let commChartFlag = String(line.substring(69, 1)).trimmingCharacters(in: .whitespaces)
    let milFreqStr = String(line.substring(70, 7)).trimmingCharacters(in: .whitespaces)
    let milChartFlag = String(line.substring(77, 1)).trimmingCharacters(in: .whitespaces)

    let facility = MiscActivityArea.ContactFacility(
      facilityId: facilityID.isEmpty ? nil : facilityID,
      facilityName: facilityName.isEmpty ? nil : facilityName,
      commercialFrequencyKHz: Double(commFreqStr).map { UInt($0 * 1000) },
      showCommercialOnChart: commChartFlag == "Y",
      militaryFrequencyKHz: Double(milFreqStr).map { UInt($0 * 1000) },
      showMilitaryOnChart: milChartFlag == "Y"
    )

    areas[MAAId]?.contactFacilities.append(facility)
  }

  private func parseCheckForNOTAMs(_ line: String, MAAId: String) throws {
    // MAA6 record format:
    // Position 1-4: Record type "MAA6"
    // Position 5-10: MAA ID (6)
    // Position 11-14: Check for NOTAMs (4)
    guard line.count >= 14 else {
      throw ParserError.truncatedRecord(
        recordType: "MAA6",
        expectedMinLength: 14,
        actualLength: line.count
      )
    }
    guard areas[MAAId] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "MiscActivityArea",
        parentID: MAAId,
        childType: "check for NOTAMs"
      )
    }
    let text = String(line.substring(10, 4)).trimmingCharacters(in: .whitespaces)
    if !text.isEmpty {
      areas[MAAId]?.checkForNOTAMs.append(text)
    }
  }

  private func parseRemarks(_ line: String, MAAId: String) throws {
    // MAA7 record format:
    // Position 1-4: Record type "MAA7"
    // Position 5-10: MAA ID (6)
    // Position 11-310: Additional remarks (300)
    guard line.count >= 310 else {
      throw ParserError.truncatedRecord(
        recordType: "MAA7",
        expectedMinLength: 310,
        actualLength: line.count
      )
    }
    guard areas[MAAId] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "MiscActivityArea",
        parentID: MAAId,
        childType: "remark"
      )
    }
    let text = String(line.substring(10, 300)).trimmingCharacters(in: .whitespaces)
    if !text.isEmpty {
      areas[MAAId]?.remarks.append(text)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(miscActivityAreas: Array(areas.values))
  }

  // MARK: - Private Helpers

  /// Creates a Location from optional lat/lon (decimal degrees), throwing if only one is present.
  /// Converts decimal degrees to arc-seconds for Location storage.
  private func makeLocation(
    latitude: Double?,
    longitude: Double?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        // Convert decimal degrees to arc-seconds (multiply by 3600)
        return Location(latitudeArcsec: Float(lat * 3600), longitudeArcsec: Float(lon * 3600))
      case (.none, .none):
        return nil
      default:
        throw ParserError.invalidLocation(
          latitude: latitude.map { Float($0) },
          longitude: longitude.map { Float($0) },
          context: context
        )
    }
  }

  private func parseYesNo(_ str: String) -> Bool? {
    switch str.uppercased() {
      case "YES", "Y": return true
      case "NO", "N": return false
      default: return nil
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
