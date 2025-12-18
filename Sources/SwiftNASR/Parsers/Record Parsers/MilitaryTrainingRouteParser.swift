import Foundation

/// Parser for MTR (Military Training Route) files.
///
/// These files contain military training route information.
/// Records are 519 characters fixed-width with MTR1 (base), MTR2 (operating procedures),
/// MTR3 (route width), MTR4 (terrain following), MTR5 (route points), and MTR6 (agencies).
class FixedWidthMilitaryTrainingRouteParser: LayoutDataParser {
  static let type = RecordType.militaryTrainingRoutes

  var formats = [NASRTable]()
  var routes = [String: MilitaryTrainingRoute]()

  func parse(data: Data) throws {
    guard let line = String(data: data, encoding: .isoLatin1) else {
      throw ParserError.badData("Invalid ISO-Latin1 encoding in MTR record")
    }
    guard line.count >= 12 else {
      throw ParserError.truncatedRecord(
        recordType: "MTR",
        expectedMinLength: 12,
        actualLength: line.count
      )
    }

    let recordType = String(line.prefix(4))
    let routeTypeStr = String(line.substring(4, 3)).trimmingCharacters(in: .whitespaces)
    let routeIdentifier = String(line.substring(7, 5)).trimmingCharacters(in: .whitespaces)

    guard !routeTypeStr.isEmpty, !routeIdentifier.isEmpty else {
      throw ParserError.missingRequiredField(field: "routeType/routeIdentifier", recordType: "MTR")
    }

    let routeKey = "\(routeTypeStr)\(routeIdentifier)"

    switch recordType {
      case "MTR1":
        try parseBaseRecord(
          line,
          routeType: routeTypeStr,
          routeIdentifier: routeIdentifier,
          key: routeKey
        )
      case "MTR2":
        try parseOperatingProcedures(line, key: routeKey)
      case "MTR3":
        try parseRouteWidth(line, key: routeKey)
      case "MTR4":
        try parseTerrainFollowing(line, key: routeKey)
      case "MTR5":
        try parseRoutePoint(line, key: routeKey)
      case "MTR6":
        try parseAgency(line, key: routeKey)
      default:
        break
    }
  }

  private func parseBaseRecord(
    _ line: String,
    routeType: String,
    routeIdentifier: String,
    key: String
  ) throws {
    // MTR1 record format (519 chars):
    // Position 1-4: Record type "MTR1"
    // Position 5-7: Route type (IR or VR)
    // Position 8-12: Route identifier (5, right-justified)
    // Position 13-20: Publication effective date YYYYMMDD (8)
    // Position 21-23: FAA region code (3)
    // Position 24-103: ARTCC identifiers, 20 occurrences of 4 chars (80)
    // Position 104-263: FSS identifiers, 40 occurrences of 4 chars (160)
    // Position 264-438: Times of use text (175)
    // Position 439-514: Blanks (76)
    // Position 515-519: Sort sequence number (5)

    guard let type = MilitaryTrainingRoute.RouteType(rawValue: routeType) else {
      throw ParserError.unknownRecordEnumValue(routeType)
    }

    let effectiveDateStr = String(line.substring(12, 8)).trimmingCharacters(in: .whitespaces)
    let FAARegion = String(line.substring(20, 3)).trimmingCharacters(in: .whitespaces)

    // Parse ARTCC identifiers (20 x 4 chars)
    var ARTCCs = [String]()
    for i in 0..<20 {
      let ARTCC = String(line.substring(23 + (i * 4), 4)).trimmingCharacters(in: .whitespaces)
      if !ARTCC.isEmpty {
        ARTCCs.append(ARTCC)
      }
    }

    // Parse FSS identifiers (40 x 4 chars)
    var FSSes = [String]()
    for i in 0..<40 {
      let FSS = String(line.substring(103 + (i * 4), 4)).trimmingCharacters(in: .whitespaces)
      if !FSS.isEmpty {
        FSSes.append(FSS)
      }
    }

    let timesOfUse = String(line.substring(263, 175)).trimmingCharacters(in: .whitespaces)

    let route = MilitaryTrainingRoute(
      routeType: type,
      routeIdentifier: routeIdentifier,
      effectiveDate: parseDate(effectiveDateStr),
      FAARegionCode: FAARegion.isEmpty ? nil : FAARegion,
      ARTCCIdentifiers: ARTCCs,
      FSSIdentifiers: FSSes,
      timesOfUse: timesOfUse.isEmpty ? nil : timesOfUse,
      operatingProcedures: [],
      routeWidthDescriptions: [],
      terrainFollowingOperations: [],
      routePoints: [],
      agencies: []
    )

    routes[key] = route
  }

  private func parseOperatingProcedures(_ line: String, key: String) throws {
    // MTR2: Position 13-112: Standard operating procedure text (100)
    guard line.count >= 112 else {
      throw ParserError.truncatedRecord(
        recordType: "MTR2",
        expectedMinLength: 112,
        actualLength: line.count
      )
    }
    guard routes[key] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "MilitaryTrainingRoute",
        parentID: key,
        childType: "operating procedures"
      )
    }
    let text = String(line.substring(12, 100)).trimmingCharacters(in: .whitespaces)
    if !text.isEmpty {
      routes[key]?.operatingProcedures.append(text)
    }
  }

  private func parseRouteWidth(_ line: String, key: String) throws {
    // MTR3: Position 13-112: Route width description text (100)
    guard line.count >= 112 else {
      throw ParserError.truncatedRecord(
        recordType: "MTR3",
        expectedMinLength: 112,
        actualLength: line.count
      )
    }
    guard routes[key] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "MilitaryTrainingRoute",
        parentID: key,
        childType: "route width"
      )
    }
    let text = String(line.substring(12, 100)).trimmingCharacters(in: .whitespaces)
    if !text.isEmpty {
      routes[key]?.routeWidthDescriptions.append(text)
    }
  }

  private func parseTerrainFollowing(_ line: String, key: String) throws {
    // MTR4: Position 13-112: Terrain following operations text (100)
    guard line.count >= 112 else {
      throw ParserError.truncatedRecord(
        recordType: "MTR4",
        expectedMinLength: 112,
        actualLength: line.count
      )
    }
    guard routes[key] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "MilitaryTrainingRoute",
        parentID: key,
        childType: "terrain following"
      )
    }
    let text = String(line.substring(12, 100)).trimmingCharacters(in: .whitespaces)
    if !text.isEmpty {
      routes[key]?.terrainFollowingOperations.append(text)
    }
  }

  private func parseRoutePoint(_ line: String, key: String) throws {
    // MTR5 record format:
    // Position 13-17: Point ID (5)
    // Position 18-245: Segment description leading (228 = 4 x 57)
    // Position 246-473: Segment description leaving (228 = 4 x 57)
    // Position 474-477: Navaid identifier (4)
    // Position 478-482: Navaid bearing (5)
    // Position 483-486: Navaid distance (4)
    // Position 487-500: Latitude (14, right-justified)
    // Position 501-514: Longitude (14, right-justified)
    // Position 515-519: Sequence number (5, right-justified)
    guard line.count >= 519 else {
      throw ParserError.truncatedRecord(
        recordType: "MTR5",
        expectedMinLength: 519,
        actualLength: line.count
      )
    }
    guard routes[key] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "MilitaryTrainingRoute",
        parentID: key,
        childType: "route point"
      )
    }

    let pointId = String(line.substring(12, 5)).trimmingCharacters(in: .whitespaces)

    // Parse leading segment descriptions (4 x 57 chars, joined since lines break mid-word)
    let leadingDesc: String? = {
      let joined = (0..<4)
        .map { String(line.substring(17 + ($0 * 57), 57)).trimmingCharacters(in: .whitespaces) }
        .joined()
      return joined.isEmpty ? nil : joined
    }()

    // Parse leaving segment descriptions (4 x 57 chars, joined since lines break mid-word)
    let leavingDesc: String? = {
      let joined = (0..<4)
        .map { String(line.substring(245 + ($0 * 57), 57)).trimmingCharacters(in: .whitespaces) }
        .joined()
      return joined.isEmpty ? nil : joined
    }()

    let navaidIdent = String(line.substring(473, 4)).trimmingCharacters(in: .whitespaces)
    let navaidBearingStr = String(line.substring(477, 5)).trimmingCharacters(in: .whitespaces)
    let navaidDistanceStr = String(line.substring(482, 4)).trimmingCharacters(in: .whitespaces)
    let latStr = String(line.substring(486, 14)).trimmingCharacters(in: .whitespaces)
    let lonStr = String(line.substring(500, 14)).trimmingCharacters(in: .whitespaces)
    let seqStr = String(line.substring(514, 5)).trimmingCharacters(in: .whitespaces)

    let position = try makeLocation(
      latitude: parseLatitude(latStr),
      longitude: parseLongitude(lonStr),
      context: "MTR route \(key) point \(pointId)"
    )

    let point = MilitaryTrainingRoute.RoutePoint(
      pointId: pointId,
      segmentDescriptionLeading: leadingDesc,
      segmentDescriptionLeaving: leavingDesc,
      navaidIdentifier: navaidIdent.isEmpty ? nil : navaidIdent,
      navaidBearingDeg: UInt(navaidBearingStr),
      navaidDistanceNM: UInt(navaidDistanceStr),
      position: position,
      sequenceNumber: UInt(seqStr)
    )

    routes[key]?.routePoints.append(point)
  }

  private func parseAgency(_ line: String, key: String) throws {
    // MTR6 record format:
    // Position 13-14: Agency type code (2)
    // Position 15-75: Organization name (61)
    // Position 76-105: Station (30)
    // Position 106-140: Address (35)
    // Position 141-170: City (30)
    // Position 171-172: State (2)
    // Position 173-182: ZIP code (10)
    // Position 183-222: Commercial phone (40)
    // Position 223-262: DSN phone (40)
    // Position 263-437: Hours (175)
    guard line.count >= 437 else {
      throw ParserError.truncatedRecord(
        recordType: "MTR6",
        expectedMinLength: 437,
        actualLength: line.count
      )
    }
    guard routes[key] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "MilitaryTrainingRoute",
        parentID: key,
        childType: "agency"
      )
    }

    let agencyTypeStr = String(line.substring(12, 2)).trimmingCharacters(in: .whitespaces)
    let orgName = String(line.substring(14, 61)).trimmingCharacters(in: .whitespaces)
    let station = String(line.substring(75, 30)).trimmingCharacters(in: .whitespaces)
    let address = String(line.substring(105, 35)).trimmingCharacters(in: .whitespaces)
    let city = String(line.substring(140, 30)).trimmingCharacters(in: .whitespaces)
    let state = String(line.substring(170, 2)).trimmingCharacters(in: .whitespaces)
    let zip = String(line.substring(172, 10)).trimmingCharacters(in: .whitespaces)
    let commPhone = String(line.substring(182, 40)).trimmingCharacters(in: .whitespaces)
    let DSNPhone = String(line.substring(222, 40)).trimmingCharacters(in: .whitespaces)
    let hours = String(line.substring(262, 175)).trimmingCharacters(in: .whitespaces)

    let agency = MilitaryTrainingRoute.Agency(
      agencyType: MilitaryTrainingRoute.AgencyType(rawValue: agencyTypeStr),
      organizationName: orgName.isEmpty ? nil : orgName,
      station: station.isEmpty ? nil : station,
      address: address.isEmpty ? nil : address,
      city: city.isEmpty ? nil : city,
      stateCode: state.isEmpty ? nil : state,
      zipCode: zip.isEmpty ? nil : zip,
      commercialPhone: commPhone.isEmpty ? nil : commPhone,
      DSNPhone: DSNPhone.isEmpty ? nil : DSNPhone,
      hours: hours.isEmpty ? nil : hours
    )

    routes[key]?.agencies.append(agency)
  }

  func finish(data: NASRData) async {
    await data.finishParsing(militaryTrainingRoutes: Array(routes.values))
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

  /// Parse date string (YYYYMMDD format)
  private func parseDate(_ str: String) -> DateComponents? {
    guard str.count == 8 else { return nil }
    guard let year = Int(str.prefix(4)),
      let month = Int(str.dropFirst(4).prefix(2)),
      let day = Int(str.dropFirst(6).prefix(2))
    else { return nil }
    return DateComponents(year: year, month: month, day: day)
  }

  /// Parse latitude string (DD-MM-SS.SSSSH or DDMMSS.SSSSH format)
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

  /// Parse longitude string (DDD-MM-SS.SSSSH or DDDMMSS.SSSSH format)
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
