import Foundation

/// Parser for HPF (Holding Pattern) files.
///
/// These files contain published holding patterns.
/// Records are 487 characters fixed-width with HP1 (base), HP2 (charting),
/// HP3 (other altitude/speed), and HP4 (remarks) record types.
actor FixedWidthHoldParser: LayoutDataParser {
  static let type = RecordType.holds

  var formats = [NASRTable]()
  var holds = [String: Hold]()

  func parse(data: Data) throws {
    guard let line = String(data: data, encoding: .isoLatin1) else {
      throw ParserError.badData("Invalid ISO-Latin1 encoding in hold record")
    }
    guard line.count >= 87 else {
      throw ParserError.truncatedRecord(
        recordType: "HPF",
        expectedMinLength: 87,
        actualLength: line.count
      )
    }

    let recordType = String(line.prefix(4)).trimmingCharacters(in: .whitespaces)

    // Common fields for all record types
    let name = String(line.substring(4, 80)).trimmingCharacters(in: .whitespaces)
    let patternNumStr = String(line.substring(84, 3)).trimmingCharacters(in: .whitespaces)
    guard let patternNum = UInt(patternNumStr) else {
      throw ParserError.invalidSequenceNumber(patternNumStr, recordType: "HPF")
    }

    let holdKey = "\(name)-\(patternNum)"

    switch recordType {
      case "HP1":
        // Base holding pattern data
        let effectiveDateStr = String(line.substring(87, 11)).trimmingCharacters(in: .whitespaces)
        let effectiveDate = parseDate(effectiveDateStr)
        let directionStr = String(line.substring(98, 3)).trimmingCharacters(in: .whitespaces)
        let bearingStr = String(line.substring(101, 3)).trimmingCharacters(in: .whitespaces)
        let azimuthStr = String(line.substring(104, 5)).trimmingCharacters(in: .whitespaces)
        let ILSIdent = String(line.substring(109, 7)).trimmingCharacters(in: .whitespaces)

        // ILS type is embedded at end of ILS identifier - need to parse from name or layout
        // From mock data: "PDK*LS" means PDK with type LS
        let (ILSIdentParsed, ILSType) = parseIdentifierWithType(ILSIdent)

        let navaidIdent = String(line.substring(116, 7)).trimmingCharacters(in: .whitespaces)
        // Navaid type is a single char at end
        let (navaidIdentParsed, navaidType) = parseNavaidIdentifierWithType(navaidIdent)

        let additionalFacility = String(line.substring(123, 12)).trimmingCharacters(
          in: .whitespaces
        )
        let inboundCourseStr = String(line.substring(135, 3)).trimmingCharacters(in: .whitespaces)
        let turnDirStr = String(line.substring(138, 3)).trimmingCharacters(in: .whitespaces)

        // Holding altitudes by speed category
        let altAll = String(line.substring(141, 7)).trimmingCharacters(in: .whitespaces)
        let alt170 = String(line.substring(148, 7)).trimmingCharacters(in: .whitespaces)
        let alt200 = String(line.substring(155, 7)).trimmingCharacters(in: .whitespaces)
        let alt265 = String(line.substring(162, 7)).trimmingCharacters(in: .whitespaces)
        let alt280 = String(line.substring(169, 7)).trimmingCharacters(in: .whitespaces)
        let alt310 = String(line.substring(176, 7)).trimmingCharacters(in: .whitespaces)

        // Fix information
        let fixInfo = String(line.substring(183, 36)).trimmingCharacters(in: .whitespaces)
        let (fixIdent, fixState, fixICAO) = parseFixInfo(fixInfo)

        let fixARTCC = String(line.substring(219, 3)).trimmingCharacters(in: .whitespaces)
        let fixLatStr = String(line.substring(222, 14)).trimmingCharacters(in: .whitespaces)
        let fixLonStr = String(line.substring(236, 14)).trimmingCharacters(in: .whitespaces)

        // Navaid ARTCC info
        let navHighARTCC = String(line.substring(250, 3)).trimmingCharacters(in: .whitespaces)
        let navLowARTCC = String(line.substring(253, 3)).trimmingCharacters(in: .whitespaces)
        let navLatStr = String(line.substring(256, 14)).trimmingCharacters(in: .whitespaces)
        let navLonStr = String(line.substring(270, 14)).trimmingCharacters(in: .whitespaces)

        // Leg length
        let legLengthStr = String(line.substring(284, 8)).trimmingCharacters(in: .whitespaces)
        let (legTime, legDist) = parseLegLength(legLengthStr)

        // Parse enums
        let holdingDirection = CardinalDirection.for(directionStr)
        let azimuthType = Hold.AzimuthType.for(azimuthStr)
        let turnDirection = parseTurnDirection(turnDirStr)

        let fixPosition = try makeLocation(
          latitude: parseLatitude(fixLatStr),
          longitude: parseLongitude(fixLonStr),
          context: "hold \(name) pattern \(patternNum) fix position"
        )

        let navaidPosition = try makeLocation(
          latitude: parseLatitude(navLatStr),
          longitude: parseLongitude(navLonStr),
          context: "hold \(name) pattern \(patternNum) navaid position"
        )

        let altitudes = try HoldingAltitudes(
          allAircraft: altAll.isEmpty ? nil : altAll,
          speed170to175kt: alt170.isEmpty ? nil : alt170,
          speed200to230kt: alt200.isEmpty ? nil : alt200,
          speed265kt: alt265.isEmpty ? nil : alt265,
          speed280kt: alt280.isEmpty ? nil : alt280,
          speed310kt: alt310.isEmpty ? nil : alt310
        )

        let hold = Hold(
          name: name,
          patternNumber: patternNum,
          effectiveDateComponents: effectiveDate,
          holdingDirection: holdingDirection,
          magneticBearingDeg: UInt(bearingStr),
          azimuthType: azimuthType,
          ILSFacilityIdentifier: ILSIdentParsed.isEmpty ? nil : ILSIdentParsed,
          ilsFacilityType: ILSType,
          navaidIdentifier: navaidIdentParsed.isEmpty ? nil : navaidIdentParsed,
          navaidFacilityType: navaidType,
          additionalFacility: additionalFacility.isEmpty ? nil : additionalFacility,
          inboundCourseDeg: UInt(inboundCourseStr),
          turnDirection: turnDirection,
          altitudes: altitudes,
          fixIdentifier: fixIdent,
          fixStateCode: fixState,
          fixICAORegion: fixICAO,
          fixARTCC: fixARTCC.isEmpty ? nil : fixARTCC,
          fixPosition: fixPosition,
          navaidHighRouteARTCC: navHighARTCC.isEmpty ? nil : navHighARTCC,
          navaidLowRouteARTCC: navLowARTCC.isEmpty ? nil : navLowARTCC,
          navaidPosition: navaidPosition,
          legTimeMin: legTime,
          legDistanceNM: legDist
        )

        holds[holdKey] = hold

      case "HP2":
        // Charting information
        guard line.count >= 110 else {
          throw ParserError.truncatedRecord(
            recordType: "HP2",
            expectedMinLength: 110,
            actualLength: line.count
          )
        }
        guard holds[holdKey] != nil else {
          throw ParserError.unknownParentRecord(
            parentType: "Hold",
            parentID: holdKey,
            childType: "charting info"
          )
        }
        let chartInfo = String(line.substring(87, 22)).trimmingCharacters(in: .whitespaces)
        if !chartInfo.isEmpty {
          holds[holdKey]?.chartingInfo.append(chartInfo)
        }

      case "HP3":
        // Other altitude/speed information
        guard line.count >= 103 else {
          throw ParserError.truncatedRecord(
            recordType: "HP3",
            expectedMinLength: 103,
            actualLength: line.count
          )
        }
        guard holds[holdKey] != nil else {
          throw ParserError.unknownParentRecord(
            parentType: "Hold",
            parentID: holdKey,
            childType: "altitude/speed info"
          )
        }
        let otherAltSpeed = String(line.substring(87, 15)).trimmingCharacters(in: .whitespaces)
        if !otherAltSpeed.isEmpty {
          holds[holdKey]?.otherAltitudeSpeed.append(otherAltSpeed)
        }

      case "HP4":
        // Remarks text
        guard line.count >= 487 else {
          throw ParserError.truncatedRecord(
            recordType: "HP4",
            expectedMinLength: 487,
            actualLength: line.count
          )
        }
        guard holds[holdKey] != nil else {
          throw ParserError.unknownParentRecord(
            parentType: "Hold",
            parentID: holdKey,
            childType: "remark"
          )
        }
        let fieldLabel = String(line.substring(87, 100)).trimmingCharacters(in: .whitespaces)
        let remarkText = String(line.substring(187, 300)).trimmingCharacters(in: .whitespaces)
        if !remarkText.isEmpty {
          let remark = FieldRemark(fieldLabel: fieldLabel, text: remarkText)
          holds[holdKey]?.remarks.append(remark)
        }

      default:
        throw ParserError.unknownRecordIdentifier(recordType)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(holds: Array(holds.values))
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

  /// Parse identifier with ILS type (e.g., "PDK*LS" → ("PDK", .ILS))
  private func parseIdentifierWithType(_ str: String) -> (String, ILSFacilityType?) {
    let parts = str.split(separator: "*")
    guard parts.count == 2 else { return (str, nil) }
    let ident = String(parts[0])
    let typeCode = String(parts[1])
    return (ident, ILSFacilityType.for(typeCode))
  }

  /// Parse navaid identifier with type code (e.g., "BTG*C" → ("BTG", .VORTAC))
  private func parseNavaidIdentifierWithType(_ str: String) -> (String, Navaid.FacilityType?) {
    let parts = str.split(separator: "*")
    guard parts.count == 2 else { return (str, nil) }
    let ident = String(parts[0])
    let typeCode = String(parts[1])
    return (ident, Navaid.FacilityType.for(typeCode))
  }

  /// Parse fix info string (e.g., "AABEE*GA*K7" → ("AABEE", "GA", "K7"))
  private func parseFixInfo(_ str: String) -> (String?, String?, String?) {
    let parts = str.split(separator: "*")
    guard !parts.isEmpty else { return (nil, nil, nil) }
    let fixIdent = !parts.isEmpty ? String(parts[0]) : nil
    let stateCode = parts.count > 1 ? String(parts[1]) : nil
    let icaoRegion = parts.count > 2 ? String(parts[2]) : nil
    return (fixIdent, stateCode, icaoRegion)
  }

  /// Parse leg length string (e.g., "/15" or "1.5/15")
  private func parseLegLength(_ str: String) -> (Double?, Double?) {
    guard !str.isEmpty else { return (nil, nil) }

    let parts = str.split(separator: "/")
    var time: Double?
    var distance: Double?

    if parts.count == 2 {
      // Time/Distance format
      if !parts[0].isEmpty {
        time = Double(parts[0])
      }
      distance = Double(parts[1])
    } else if parts.count == 1 {
      // Check if it starts with /
      if str.hasPrefix("/") {
        distance = Double(parts[0])
      } else {
        time = Double(parts[0])
      }
    }

    return (time, distance)
  }

  /// Parse turn direction string
  private func parseTurnDirection(_ str: String) -> LateralDirection? {
    if str.contains("L") { return .left }
    if str.contains("R") { return .right }
    return nil
  }

  /// Parse latitude string (e.g., "34-04-05.000N")
  private func parseLatitude(_ str: String) -> Double? {
    guard !str.isEmpty else { return nil }
    // Format: DD-MM-SS.SSSN or DD-MM-SS.SSSS
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

  /// Parse longitude string (e.g., "084-12-51.710W")
  private func parseLongitude(_ str: String) -> Double? {
    guard !str.isEmpty else { return nil }
    // Format: DDD-MM-SS.SSSW or DDD-MM-SS.SSSS
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

  /// Parse date string (DD MMM YYYY format, e.g., "30 DEC 2021")
  private func parseDate(_ str: String) -> DateComponents? {
    guard !str.isEmpty else { return nil }
    return DateFormat.dayMonthYear.parse(str)
  }
}
