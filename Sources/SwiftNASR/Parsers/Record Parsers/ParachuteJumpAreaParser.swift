import Foundation

/// Parser for PJA (Parachute Jump Area) files.
///
/// These files contain parachute jump area information.
/// Records are 473 characters fixed-width with PJA1 (base), PJA2 (times),
/// PJA3 (user groups), PJA4 (contact facilities), and PJA5 (remarks) record types.
class FixedWidthParachuteJumpAreaParser: LayoutDataParser {
  static let type = RecordType.parachuteJumpAreas

  var formats = [NASRTable]()
  var areas = [String: ParachuteJumpArea]()

  func parse(data: Data) throws {
    guard let line = String(data: data, encoding: .isoLatin1) else {
      throw ParserError.badData("Invalid ISO-Latin1 encoding in PJA record")
    }
    guard line.count >= 11 else {
      throw ParserError.truncatedRecord(
        recordType: "PJA",
        expectedMinLength: 11,
        actualLength: line.count
      )
    }

    let recordType = String(line.prefix(4))
    let PJAId = String(line.substring(4, 6)).trimmingCharacters(in: .whitespaces)

    guard !PJAId.isEmpty else {
      throw ParserError.missingRequiredField(field: "PJAId", recordType: "PJA")
    }

    switch recordType {
      case "PJA1":
        try parseBaseRecord(line, PJAId: PJAId)
      case "PJA2":
        try parseTimesOfUse(line, PJAId: PJAId)
      case "PJA3":
        try parseUserGroup(line, PJAId: PJAId)
      case "PJA4":
        try parseContactFacility(line, PJAId: PJAId)
      case "PJA5":
        try parseRemarks(line, PJAId: PJAId)
      default:
        break
    }
  }

  private func parseBaseRecord(_ line: String, PJAId: String) throws {
    // PJA1 record format (473 chars):
    // Position 1-4: Record type "PJA1"
    // Position 5-10: PJA ID (6)
    // Position 11-14: Navaid identifier (4)
    // Position 15-16: Navaid facility type code (2)
    // Position 17-41: Navaid facility type described (25)
    // Position 42-47: Azimuth from navaid (6)
    // Position 48-55: Distance from navaid (8)
    // Position 56-85: Navaid name (30)
    // Position 86-87: State abbreviation (2)
    // Position 88-117: State name (30)
    // Position 118-147: City name (30)
    // Position 148-161: Latitude formatted (14)
    // Position 162-173: Latitude seconds (12)
    // Position 174-188: Longitude formatted (15)
    // Position 189-200: Longitude seconds (12)
    // Position 201-250: Airport name (50)
    // Position 251-261: Airport site number (11)
    // Position 262-311: Drop zone name (50)
    // Position 312-319: Max altitude (8)
    // Position 320-324: Radius NM (5, right-justified)
    // Position 325-327: Sectional charting required (3)
    // Position 328-330: Published in AFD (3)
    // Position 331-430: Additional description (100)
    // Position 431-434: FSS identifier (4)
    // Position 435-464: FSS name (30)
    // Position 465-472: PJA use (8)
    // Position 473: Volume (1)

    let navaidIdent = String(line.substring(10, 4)).trimmingCharacters(in: .whitespaces)
    let navaidTypeCode = String(line.substring(14, 2)).trimmingCharacters(in: .whitespaces)
    let navaidType = String(line.substring(16, 25)).trimmingCharacters(in: .whitespaces)
    let azimuthStr = String(line.substring(41, 6)).trimmingCharacters(in: .whitespaces)
    let distanceStr = String(line.substring(47, 8)).trimmingCharacters(in: .whitespaces)
    let navaidName = String(line.substring(55, 30)).trimmingCharacters(in: .whitespaces)
    let stateCode = String(line.substring(85, 2)).trimmingCharacters(in: .whitespaces)
    let stateName = String(line.substring(87, 30)).trimmingCharacters(in: .whitespaces)
    let city = String(line.substring(117, 30)).trimmingCharacters(in: .whitespaces)
    let latFormatted = String(line.substring(147, 14)).trimmingCharacters(in: .whitespaces)
    let lonFormatted = String(line.substring(173, 15)).trimmingCharacters(in: .whitespaces)
    let airportName = String(line.substring(200, 50)).trimmingCharacters(in: .whitespaces)
    let airportSiteNum = String(line.substring(250, 11)).trimmingCharacters(in: .whitespaces)
    let dropZone = String(line.substring(261, 50)).trimmingCharacters(in: .whitespaces)
    let maxAlt = String(line.substring(311, 8)).trimmingCharacters(in: .whitespaces)
    let radiusStr = String(line.substring(319, 5)).trimmingCharacters(in: .whitespaces)
    let sectionalStr = String(line.substring(324, 3)).trimmingCharacters(in: .whitespaces)
    let afdStr = String(line.substring(327, 3)).trimmingCharacters(in: .whitespaces)
    let additionalDesc = String(line.substring(330, 100)).trimmingCharacters(in: .whitespaces)
    let FSSIdent = String(line.substring(430, 4)).trimmingCharacters(in: .whitespaces)
    let FSSName = String(line.substring(434, 30)).trimmingCharacters(in: .whitespaces)
    let useTypeStr =
      line.count >= 472 ? String(line.substring(464, 8)).trimmingCharacters(in: .whitespaces) : nil
    let useType = useTypeStr.flatMap { ParachuteJumpArea.UseType(rawValue: $0) }

    let lat = parseLatitude(latFormatted)
    let lon = parseLongitude(lonFormatted)
    let position = try makeLocation(
      latitude: lat,
      longitude: lon,
      context: "PJA \(PJAId) position"
    )

    let area = ParachuteJumpArea(
      PJAId: PJAId,
      navaidIdentifier: navaidIdent.isEmpty ? nil : navaidIdent,
      navaidFacilityTypeCode: navaidTypeCode.isEmpty ? nil : navaidTypeCode,
      navaidFacilityType: navaidType.isEmpty ? nil : navaidType,
      azimuthFromNavaid: Double(azimuthStr),
      distanceFromNavaid: Double(distanceStr),
      navaidName: navaidName.isEmpty ? nil : navaidName,
      stateCode: stateCode.isEmpty ? nil : stateCode,
      stateName: stateName.isEmpty ? nil : stateName,
      city: city.isEmpty ? nil : city,
      position: position,
      airportName: airportName.isEmpty ? nil : airportName,
      airportSiteNumber: airportSiteNum.isEmpty ? nil : airportSiteNum,
      dropZoneName: dropZone.isEmpty ? nil : dropZone,
      maxAltitude: maxAlt.isEmpty ? nil : try Altitude(parsing: maxAlt),
      radius: Double(radiusStr),
      sectionalChartingRequired: parseYesNo(sectionalStr),
      publishedInAFD: parseYesNo(afdStr),
      additionalDescription: additionalDesc.isEmpty ? nil : additionalDesc,
      FSSIdentifier: FSSIdent.isEmpty ? nil : FSSIdent,
      FSSName: FSSName.isEmpty ? nil : FSSName,
      useType: useType,
      timesOfUse: [],
      userGroups: [],
      contactFacilities: [],
      remarks: []
    )

    areas[PJAId] = area
  }

  private func parseTimesOfUse(_ line: String, PJAId: String) throws {
    // PJA2: Position 11-85: Times of use description (75)
    guard line.count >= 85 else {
      throw ParserError.truncatedRecord(
        recordType: "PJA2",
        expectedMinLength: 85,
        actualLength: line.count
      )
    }
    guard areas[PJAId] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "ParachuteJumpArea",
        parentID: PJAId,
        childType: "times of use"
      )
    }
    let timesOfUse = String(line.substring(10, 75)).trimmingCharacters(in: .whitespaces)
    if !timesOfUse.isEmpty {
      areas[PJAId]?.timesOfUse.append(timesOfUse)
    }
  }

  private func parseUserGroup(_ line: String, PJAId: String) throws {
    // PJA3: Position 11-85: User group name (75)
    // Position 86-160: Description (75)
    guard line.count >= 160 else {
      throw ParserError.truncatedRecord(
        recordType: "PJA3",
        expectedMinLength: 160,
        actualLength: line.count
      )
    }
    guard areas[PJAId] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "ParachuteJumpArea",
        parentID: PJAId,
        childType: "user group"
      )
    }
    let name = String(line.substring(10, 75)).trimmingCharacters(in: .whitespaces)
    let description = String(line.substring(85, 75)).trimmingCharacters(in: .whitespaces)

    if !name.isEmpty {
      let userGroup = ParachuteJumpArea.UserGroup(
        name: name,
        description: description.isEmpty ? nil : description
      )
      areas[PJAId]?.userGroups.append(userGroup)
    }
  }

  private func parseContactFacility(_ line: String, PJAId: String) throws {
    // PJA4 record format:
    // Position 11-14: Contact facility ID (4)
    // Position 15-62: Contact facility name (48)
    // Position 63-66: Related location ID (4)
    // Position 67-74: Commercial frequency (8, right-justified)
    // Position 75: Commercial chart flag (1)
    // Position 76-83: Military frequency (8, right-justified)
    // Position 84: Military chart flag (1)
    // Position 85-114: Sector (30)
    // Position 115-134: Altitude (20, right-justified)
    guard line.count >= 134 else {
      throw ParserError.truncatedRecord(
        recordType: "PJA4",
        expectedMinLength: 134,
        actualLength: line.count
      )
    }
    guard areas[PJAId] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "ParachuteJumpArea",
        parentID: PJAId,
        childType: "contact facility"
      )
    }

    let facilityID = String(line.substring(10, 4)).trimmingCharacters(in: .whitespaces)
    let facilityName = String(line.substring(14, 48)).trimmingCharacters(in: .whitespaces)
    let relatedLocID = String(line.substring(62, 4)).trimmingCharacters(in: .whitespaces)
    let commFreqStr = String(line.substring(66, 8)).trimmingCharacters(in: .whitespaces)
    let commChartFlag = String(line.substring(74, 1)).trimmingCharacters(in: .whitespaces)
    let milFreqStr = String(line.substring(75, 8)).trimmingCharacters(in: .whitespaces)
    let milChartFlag = String(line.substring(83, 1)).trimmingCharacters(in: .whitespaces)
    let sector = String(line.substring(84, 30)).trimmingCharacters(in: .whitespaces)
    let altitude = String(line.substring(114, 20)).trimmingCharacters(in: .whitespaces)

    let facility = ParachuteJumpArea.ContactFacility(
      facilityId: facilityID.isEmpty ? nil : facilityID,
      facilityName: facilityName.isEmpty ? nil : facilityName,
      relatedLocationId: relatedLocID.isEmpty ? nil : relatedLocID,
      commercialFrequency: Double(commFreqStr).map { UInt($0 * 1000) },
      commercialCharted: commChartFlag == "Y",
      militaryFrequency: Double(milFreqStr).map { UInt($0 * 1000) },
      militaryCharted: milChartFlag == "Y",
      sector: sector.isEmpty ? nil : sector,
      altitude: altitude.isEmpty ? nil : altitude
    )

    areas[PJAId]?.contactFacilities.append(facility)
  }

  private func parseRemarks(_ line: String, PJAId: String) throws {
    // PJA5: Position 11-310: Additional remarks (300)
    guard line.count >= 310 else {
      throw ParserError.truncatedRecord(
        recordType: "PJA5",
        expectedMinLength: 310,
        actualLength: line.count
      )
    }
    guard areas[PJAId] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "ParachuteJumpArea",
        parentID: PJAId,
        childType: "remark"
      )
    }
    let remarks = String(line.substring(10, 300)).trimmingCharacters(in: .whitespaces)
    if !remarks.isEmpty {
      areas[PJAId]?.remarks.append(remarks)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(parachuteJumpAreas: Array(areas.values))
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
        return Location(latitude: Float(lat * 3600), longitude: Float(lon * 3600))
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

  /// Parse latitude string (DD-MM-SS.SSSSH format)
  private func parseLatitude(_ str: String) -> Double? {
    guard !str.isEmpty else { return nil }
    // Format: DD-MM-SS.SSSSH (e.g., "61-18-47.4645N")
    let isNorth = str.hasSuffix("N")
    let isSouth = str.hasSuffix("S")
    var working = str
    if isNorth || isSouth {
      working = String(str.dropLast())
    }

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

  /// Parse longitude string (DDD-MM-SS.SSSSH format)
  private func parseLongitude(_ str: String) -> Double? {
    guard !str.isEmpty else { return nil }
    // Format: DDD-MM-SS.SSSSH (e.g., "149-33-55.9086W")
    let isWest = str.hasSuffix("W")
    let isEast = str.hasSuffix("E")
    var working = str
    if isWest || isEast {
      working = String(str.dropLast())
    }

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

  /// Parse YES/NO string to Bool
  private func parseYesNo(_ str: String) -> Bool? {
    switch str.uppercased() {
      case "YES", "Y": return true
      case "NO", "N": return false
      default: return nil
    }
  }
}
