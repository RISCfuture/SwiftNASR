import Foundation

/// Parser for ATS (Air Traffic Service) Airway files.
///
/// These files contain ATS route information including Atlantic, Bahama, Pacific,
/// and Puerto Rico routes. Records are 355 characters fixed-width with 6 record types:
/// ATS1 (base/MEA data), ATS2 (point description), ATS3 (changeover point),
/// ATS4 (point remarks), ATS5 (changeover exceptions), and RMK (route remarks).
class FixedWidthATSAirwayParser: Parser {
  var airways = [String: ATSAirway]()
  var pointData = [String: [UInt: ATSAirway.RoutePoint]]()

  func prepare(distribution _: Distribution) throws {
    // No layout file parsing needed
  }

  func parse(data: Data) throws {
    guard let line = String(data: data, encoding: .isoLatin1) else {
      throw ParserError.badData("Invalid ISO-Latin1 encoding in ATS record")
    }
    guard line.count >= 26 else {
      throw ParserError.truncatedRecord(
        recordType: "ATS",
        expectedMinLength: 26,
        actualLength: line.count
      )
    }

    let recordType = String(line.substring(0, 4)).trimmingCharacters(in: .whitespaces)

    // Common header fields for all record types
    let designation = String(line.substring(4, 2)).trimmingCharacters(in: .whitespaces)
    let airwayId = String(line.substring(6, 12)).trimmingCharacters(in: .whitespaces)
    let rnavIndicator = String(line.substring(18, 1)).trimmingCharacters(in: .whitespaces)
    let airwayType = String(line.substring(19, 1)).trimmingCharacters(in: .whitespaces)

    guard !airwayId.isEmpty else {
      throw ParserError.missingRequiredField(field: "airwayId", recordType: "ATS")
    }

    let airwayKey = "\(designation)\(airwayId)\(rnavIndicator)\(airwayType)"

    switch recordType {
      case "ATS1":
        try parseATS1(
          line,
          key: airwayKey,
          designation: designation,
          airwayId: airwayId,
          rnavIndicator: rnavIndicator,
          airwayType: airwayType
        )
      case "ATS2":
        try parseATS2(line, key: airwayKey)
      case "ATS3":
        try parseATS3(line, key: airwayKey)
      case "ATS4":
        try parseATS4(line, key: airwayKey)
      case "ATS5":
        try parseATS5(line, key: airwayKey)
      case "RMK":
        try parseRMK(line, key: airwayKey)
      default:
        break
    }
  }

  private func parseATS1(
    _ line: String,
    key: String,
    designation: String,
    airwayId: String,
    rnavIndicator: String,
    airwayType: String
  ) throws {
    // ATS1 record - Base and MEA data (355 chars)
    let seqStr = String(line.substring(20, 5)).trimmingCharacters(in: .whitespaces)
    let effectiveDateStr = String(line.substring(25, 10)).trimmingCharacters(in: .whitespaces)
    let effectiveDate = parseDate(effectiveDateStr)
    let trackOutbound = String(line.substring(35, 7)).trimmingCharacters(in: .whitespaces)
    let distCOP = String(line.substring(42, 5)).trimmingCharacters(in: .whitespaces)
    let trackInbound = String(line.substring(47, 7)).trimmingCharacters(in: .whitespaces)
    let distNextPt = String(line.substring(54, 6)).trimmingCharacters(in: .whitespaces)
    let magCourse = String(line.substring(66, 6)).trimmingCharacters(in: .whitespaces)
    let magCourseOpp = String(line.substring(72, 6)).trimmingCharacters(in: .whitespaces)
    let MEAStr = String(line.substring(84, 5)).trimmingCharacters(in: .whitespaces)
    let MEADir = String(line.substring(89, 7)).trimmingCharacters(in: .whitespaces)
    let MEAOppStr = String(line.substring(96, 5)).trimmingCharacters(in: .whitespaces)
    let MEAOppDir = String(line.substring(101, 7)).trimmingCharacters(in: .whitespaces)
    let maxAlt = String(line.substring(108, 5)).trimmingCharacters(in: .whitespaces)
    let moca = String(line.substring(113, 5)).trimmingCharacters(in: .whitespaces)
    let gapFlag = String(line.substring(118, 1)).trimmingCharacters(in: .whitespaces)
    let copDist = String(line.substring(119, 3)).trimmingCharacters(in: .whitespaces)
    let mca = String(line.substring(122, 5)).trimmingCharacters(in: .whitespaces)
    let mcaDir = String(line.substring(127, 7)).trimmingCharacters(in: .whitespaces)
    let mcaOpp = String(line.substring(134, 5)).trimmingCharacters(in: .whitespaces)
    let mcaOppDir = String(line.substring(139, 7)).trimmingCharacters(in: .whitespaces)
    let sigGap = String(line.substring(146, 1)).trimmingCharacters(in: .whitespaces)
    let usOnly = String(line.substring(147, 1)).trimmingCharacters(in: .whitespaces)
    let magVar = String(line.substring(148, 5)).trimmingCharacters(in: .whitespaces)
    let artcc = String(line.substring(153, 3)).trimmingCharacters(in: .whitespaces)
    let gnssMea = String(line.substring(246, 5)).trimmingCharacters(in: .whitespaces)
    let gnssMeaDir = String(line.substring(251, 7)).trimmingCharacters(in: .whitespaces)
    let gnssMeaOpp = String(line.substring(258, 5)).trimmingCharacters(in: .whitespaces)
    let gnssMeaOppDir = String(line.substring(263, 7)).trimmingCharacters(in: .whitespaces)
    let DME_MEA = String(line.substring(320, 5)).trimmingCharacters(in: .whitespaces)
    let DME_MEADir = String(line.substring(325, 6)).trimmingCharacters(in: .whitespaces)
    let DME_MEAOpp = String(line.substring(331, 5)).trimmingCharacters(in: .whitespaces)
    let DME_MEAOppDir = String(line.substring(336, 6)).trimmingCharacters(in: .whitespaces)
    let dogleg = String(line.substring(342, 1)).trimmingCharacters(in: .whitespaces)
    let rnpStr = String(line.substring(343, 5)).trimmingCharacters(in: .whitespaces)

    guard let seqNum = UInt(seqStr) else {
      throw ParserError.invalidSequenceNumber(seqStr, recordType: "ATS1")
    }

    // Parse magnetic variation first for use in course bearing creation
    let magneticVariation = try parseMagneticVariation(magVar)

    // Convert magnetic course values to Bearing<Double>
    let magneticCourseValue = Double(magCourse)
    let magneticCourse = magneticCourseValue.map { value in
      Bearing(value, reference: .magnetic, magneticVariationDeg: magneticVariation ?? 0)
    }
    let magneticCourseOppValue = Double(magCourseOpp)
    let magneticCourseOpposite = magneticCourseOppValue.map { value in
      Bearing(value, reference: .magnetic, magneticVariationDeg: magneticVariation ?? 0)
    }

    // Create or update airway
    if airways[key] == nil {
      guard let designationEnum = ATSAirway.Designation(rawValue: designation) else {
        throw ParserError.invalidValue(designation)
      }
      let airwayTypeEnum: ATSAirway.AirwayType
      if airwayType.isEmpty {
        airwayTypeEnum = .general
      } else {
        guard let parsed = ATSAirway.AirwayType(rawValue: airwayType) else {
          throw ParserError.invalidValue(airwayType)
        }
        airwayTypeEnum = parsed
      }
      guard let effectiveDateValue = effectiveDate else {
        throw ParserError.missingRequiredField(field: "effectiveDate", recordType: "ATS1")
      }
      airways[key] = ATSAirway(
        designation: designationEnum,
        airwayIdentifier: airwayId,
        isRNAV: rnavIndicator == "R",
        airwayType: airwayTypeEnum,
        effectiveDate: effectiveDateValue,
        routePoints: [],
        routeRemarks: []
      )
      pointData[key] = [:]
    }

    // Create route point with ATS1 data
    let point = ATSAirway.RoutePoint(
      sequenceNumber: seqNum,
      pointName: nil,
      pointType: nil,
      isNamedFix: false,
      stateCode: nil,
      ICAORegionCode: nil,
      position: nil,
      minimumReceptionAltitudeFt: nil,
      navaidIdentifier: nil,
      trackAngleOutbound: trackOutbound.isEmpty ? nil : try TrackAnglePair(parsing: trackOutbound),
      distanceToChangeoverPointNM: UInt(distCOP),
      trackAngleInbound: trackInbound.isEmpty ? nil : try TrackAnglePair(parsing: trackInbound),
      distanceToNextPointNM: Double(distNextPt),
      magneticCourse: magneticCourse,
      magneticCourseOpposite: magneticCourseOpposite,
      minimumEnrouteAltitudeFt: UInt(MEAStr),
      MEADirection: try parseBoundDirection(MEADir),
      MEAOppositeAltitudeFt: UInt(MEAOppStr),
      MEAOppositeDirection: try parseBoundDirection(MEAOppDir),
      maximumAuthorizedAltitudeFt: UInt(maxAlt),
      minimumObstructionClearanceAltitudeFt: UInt(moca),
      hasAirwayGap: gapFlag == "X",
      changeoverPointDistanceNM: UInt(copDist),
      minimumCrossingAltitudeFt: UInt(mca),
      crossingDirection: try parseBoundDirection(mcaDir),
      crossingAltitudeOppositeFt: UInt(mcaOpp),
      crossingDirectionOpposite: try parseBoundDirection(mcaOppDir),
      hasSignalGap: sigGap == "Y",
      usAirspaceOnly: usOnly == "Y",
      magneticVariationDeg: magneticVariation,
      ARTCCIdentifier: artcc.isEmpty ? nil : artcc,
      GNSS_MEAFt: UInt(gnssMea),
      GNSS_MEADirection: try parseBoundDirection(gnssMeaDir),
      GNSS_MEAOppositeFt: UInt(gnssMeaOpp),
      GNSS_MEAOppositeDirection: try parseBoundDirection(gnssMeaOppDir),
      DME_DME_IRU_MEAFt: UInt(DME_MEA),
      DME_DME_IRU_MEADirection: try parseBoundDirection(DME_MEADir),
      DME_DME_IRU_MEAOppositeFt: UInt(DME_MEAOpp),
      DME_DME_IRU_MEAOppositeDirection: try parseBoundDirection(DME_MEAOppDir),
      isDogleg: dogleg == "Y",
      RNP_NM: Double(rnpStr),
      changeoverNavaidName: nil,
      changeoverNavaidType: nil,
      changeoverNavaidStateCode: nil,
      changeoverNavaidPosition: nil,
      remarks: [],
      changeoverExceptions: []
    )

    pointData[key]?[seqNum] = point
  }

  private func parseATS2(_ line: String, key: String) throws {
    // ATS2 record - Point description
    let seqStr = String(line.substring(20, 5)).trimmingCharacters(in: .whitespaces)
    let pointName = String(line.substring(25, 40)).trimmingCharacters(in: .whitespaces)
    let pointType = String(line.substring(65, 25)).trimmingCharacters(in: .whitespaces)
    let fixCategory = String(line.substring(90, 15)).trimmingCharacters(in: .whitespaces)
    let stateCode = String(line.substring(105, 2)).trimmingCharacters(in: .whitespaces)
    let icaoCode = String(line.substring(107, 2)).trimmingCharacters(in: .whitespaces)
    let latStr = String(line.substring(109, 14)).trimmingCharacters(in: .whitespaces)
    let lonStr = String(line.substring(123, 14)).trimmingCharacters(in: .whitespaces)
    let mraStr = String(line.substring(137, 5)).trimmingCharacters(in: .whitespaces)
    let navaidId = String(line.substring(142, 4)).trimmingCharacters(in: .whitespaces)

    guard let seqNum = UInt(seqStr) else {
      throw ParserError.invalidSequenceNumber(seqStr, recordType: "ATS2")
    }

    guard var point = pointData[key]?[seqNum] else {
      throw ParserError.unknownParentRecord(
        parentType: "ATSAirway",
        parentID: "\(key) seq \(seqNum)",
        childType: "point description"
      )
    }

    let lat = parseLatitude(latStr)
    let lon = parseLongitude(lonStr)
    let position = try makeLocation(
      latitude: lat,
      longitude: lon,
      context: "ATS airway \(key) point \(seqNum)"
    )

    // Update point with ATS2 data
    point = ATSAirway.RoutePoint(
      sequenceNumber: point.sequenceNumber,
      pointName: pointName.isEmpty ? nil : pointName,
      pointType: ATSAirway.PointType(rawValue: pointType),
      isNamedFix: try parseIsNamedFix(fixCategory),
      stateCode: stateCode.isEmpty ? nil : stateCode,
      ICAORegionCode: icaoCode.isEmpty ? nil : icaoCode,
      position: position,
      minimumReceptionAltitudeFt: UInt(mraStr),
      navaidIdentifier: navaidId.isEmpty ? nil : navaidId,
      trackAngleOutbound: point.trackAngleOutbound,
      distanceToChangeoverPointNM: point.distanceToChangeoverPointNM,
      trackAngleInbound: point.trackAngleInbound,
      distanceToNextPointNM: point.distanceToNextPointNM,
      magneticCourse: point.magneticCourse,
      magneticCourseOpposite: point.magneticCourseOpposite,
      minimumEnrouteAltitudeFt: point.minimumEnrouteAltitudeFt,
      MEADirection: point.MEADirection,
      MEAOppositeAltitudeFt: point.MEAOppositeAltitudeFt,
      MEAOppositeDirection: point.MEAOppositeDirection,
      maximumAuthorizedAltitudeFt: point.maximumAuthorizedAltitudeFt,
      minimumObstructionClearanceAltitudeFt: point.minimumObstructionClearanceAltitudeFt,
      hasAirwayGap: point.hasAirwayGap,
      changeoverPointDistanceNM: point.changeoverPointDistanceNM,
      minimumCrossingAltitudeFt: point.minimumCrossingAltitudeFt,
      crossingDirection: point.crossingDirection,
      crossingAltitudeOppositeFt: point.crossingAltitudeOppositeFt,
      crossingDirectionOpposite: point.crossingDirectionOpposite,
      hasSignalGap: point.hasSignalGap,
      usAirspaceOnly: point.usAirspaceOnly,
      magneticVariationDeg: point.magneticVariationDeg,
      ARTCCIdentifier: point.ARTCCIdentifier,
      GNSS_MEAFt: point.GNSS_MEAFt,
      GNSS_MEADirection: point.GNSS_MEADirection,
      GNSS_MEAOppositeFt: point.GNSS_MEAOppositeFt,
      GNSS_MEAOppositeDirection: point.GNSS_MEAOppositeDirection,
      DME_DME_IRU_MEAFt: point.DME_DME_IRU_MEAFt,
      DME_DME_IRU_MEADirection: point.DME_DME_IRU_MEADirection,
      DME_DME_IRU_MEAOppositeFt: point.DME_DME_IRU_MEAOppositeFt,
      DME_DME_IRU_MEAOppositeDirection: point.DME_DME_IRU_MEAOppositeDirection,
      isDogleg: point.isDogleg,
      RNP_NM: point.RNP_NM,
      changeoverNavaidName: point.changeoverNavaidName,
      changeoverNavaidType: point.changeoverNavaidType,
      changeoverNavaidStateCode: point.changeoverNavaidStateCode,
      changeoverNavaidPosition: point.changeoverNavaidPosition,
      remarks: point.remarks,
      changeoverExceptions: point.changeoverExceptions
    )

    pointData[key]?[seqNum] = point
  }

  private func parseATS3(_ line: String, key: String) throws {
    // ATS3 record - Changeover point navaid
    let seqStr = String(line.substring(20, 5)).trimmingCharacters(in: .whitespaces)
    let navName = String(line.substring(25, 30)).trimmingCharacters(in: .whitespaces)
    let navType = String(line.substring(55, 25)).trimmingCharacters(in: .whitespaces)
    let stateCode = String(line.substring(80, 2)).trimmingCharacters(in: .whitespaces)
    let latStr = String(line.substring(82, 14)).trimmingCharacters(in: .whitespaces)
    let lonStr = String(line.substring(96, 14)).trimmingCharacters(in: .whitespaces)

    guard let seqNum = UInt(seqStr) else {
      throw ParserError.invalidSequenceNumber(seqStr, recordType: "ATS3")
    }

    guard var point = pointData[key]?[seqNum] else {
      throw ParserError.unknownParentRecord(
        parentType: "ATSAirway",
        parentID: "\(key) seq \(seqNum)",
        childType: "changeover point"
      )
    }

    let copLat = parseLatitude(latStr)
    let copLon = parseLongitude(lonStr)
    let copPosition = try makeLocation(
      latitude: copLat,
      longitude: copLon,
      context: "ATS airway \(key) changeover point \(seqNum)"
    )

    point.changeoverNavaidName = navName.isEmpty ? nil : navName
    point.changeoverNavaidType = navType.isEmpty ? nil : ATSAirway.PointType(rawValue: navType)
    point.changeoverNavaidStateCode = stateCode.isEmpty ? nil : stateCode
    point.changeoverNavaidPosition = copPosition

    pointData[key]?[seqNum] = point
  }

  private func parseATS4(_ line: String, key: String) throws {
    // ATS4 record - Point remarks
    let seqStr = String(line.substring(20, 5)).trimmingCharacters(in: .whitespaces)
    let remark = String(line.substring(25, 200)).trimmingCharacters(in: .whitespaces)

    guard let seqNum = UInt(seqStr) else {
      throw ParserError.invalidSequenceNumber(seqStr, recordType: "ATS4")
    }

    guard var point = pointData[key]?[seqNum] else {
      throw ParserError.unknownParentRecord(
        parentType: "ATSAirway",
        parentID: "\(key) seq \(seqNum)",
        childType: "point remark"
      )
    }
    guard !remark.isEmpty else { return }
    point.remarks.append(remark)
    pointData[key]?[seqNum] = point
  }

  private func parseATS5(_ line: String, key: String) throws {
    // ATS5 record - Changeover exceptions
    let seqStr = String(line.substring(20, 5)).trimmingCharacters(in: .whitespaces)
    let exception = String(line.substring(25, 200)).trimmingCharacters(in: .whitespaces)

    guard let seqNum = UInt(seqStr) else {
      throw ParserError.invalidSequenceNumber(seqStr, recordType: "ATS5")
    }

    guard var point = pointData[key]?[seqNum] else {
      throw ParserError.unknownParentRecord(
        parentType: "ATSAirway",
        parentID: "\(key) seq \(seqNum)",
        childType: "changeover exception"
      )
    }
    guard !exception.isEmpty else { return }
    point.changeoverExceptions.append(exception)
    pointData[key]?[seqNum] = point
  }

  private func parseRMK(_ line: String, key: String) throws {
    // RMK record - Route remarks
    let remark = String(line.substring(28, 200)).trimmingCharacters(in: .whitespaces)
    guard airways[key] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "ATSAirway",
        parentID: key,
        childType: "route remark"
      )
    }
    guard !remark.isEmpty else { return }
    airways[key]?.routeRemarks.append(remark)
  }

  func finish(data: NASRData) async {
    // Assemble route points into airways
    for (key, points) in pointData {
      let sortedPoints = points.values.sorted { $0.sequenceNumber < $1.sequenceNumber }
      airways[key]?.routePoints = sortedPoints
    }

    await data.finishParsing(atsAirways: Array(airways.values))
  }

  // MARK: - Private Helpers

  /// Creates a Location from optional lat/lon, throwing if only one is present.
  private func makeLocation(
    latitude: Double?,
    longitude: Double?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        return Location(latitudeDeg: lat, longitudeDeg: lon)
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

  private func parseLatitude(_ str: String) -> Double? {
    guard !str.isEmpty else { return nil }

    let isNorth = str.hasSuffix("N")
    let isSouth = str.hasSuffix("S")
    var working = str
    if isNorth || isSouth {
      working = String(str.dropLast())
    }

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

    guard working.count >= 6 else { return nil }
    guard let degrees = Double(working.prefix(2)),
      let minutes = Double(working.dropFirst(2).prefix(2)),
      let seconds = Double(working.dropFirst(4))
    else { return nil }

    var lat = degrees + (minutes / 60.0) + (seconds / 3600.0)
    if isSouth { lat = -lat }
    return lat
  }

  private func parseLongitude(_ str: String) -> Double? {
    guard !str.isEmpty else { return nil }

    let isWest = str.hasSuffix("W")
    let isEast = str.hasSuffix("E")
    var working = str
    if isWest || isEast {
      working = String(str.dropLast())
    }

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

    guard working.count >= 7 else { return nil }
    guard let degrees = Double(working.prefix(3)),
      let minutes = Double(working.dropFirst(3).prefix(2)),
      let seconds = Double(working.dropFirst(5))
    else { return nil }

    var lon = degrees + (minutes / 60.0) + (seconds / 3600.0)
    if isWest { lon = -lon }
    return lon
  }

  /// Parse date string (MM/DD/YYYY format, e.g., "12/02/2021")
  private func parseDate(_ str: String) -> DateComponents? {
    guard !str.isEmpty else { return nil }
    return DateFormat.monthDayYearSlash.parse(str)
  }

  /// Parse fix type publication category - must be "FIX" or empty
  private func parseIsNamedFix(_ str: String) throws -> Bool {
    switch str {
      case "FIX": return true
      case "": return false
      default: throw ParserError.invalidValue(str)
    }
  }

  /// Parse a bound direction string (e.g., "E BND", "SE BND").
  private func parseBoundDirection(_ str: String) throws -> BoundDirection? {
    guard !str.isEmpty else { return nil }
    // Handle the case where only "BND" appears without a direction prefix
    if str == "BND" { return nil }
    guard let direction = BoundDirection(rawValue: str) else {
      throw ParserError.invalidValue(str)
    }
    return direction
  }

  /// Parse magnetic variation from format like "10W", "02E" (degrees; positive is east).
  private func parseMagneticVariation(_ str: String) throws -> Int? {
    guard !str.isEmpty else { return nil }

    let isWest = str.hasSuffix("W")
    let isEast = str.hasSuffix("E")

    guard isWest || isEast else {
      throw ParserError.invalidValue(str)
    }

    let numberPart = str.dropLast()
    guard let value = Int(numberPart.trimmingCharacters(in: .whitespaces)) else {
      throw ParserError.invalidValue(str)
    }

    return isWest ? -value : value
  }
}
