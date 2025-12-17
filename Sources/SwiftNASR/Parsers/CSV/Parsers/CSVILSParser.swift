import Foundation
import StreamingCSV
import ZIPFoundation

/// CSV ILS Parser for parsing ILS_BASE.csv, ILS_GS.csv, ILS_DME.csv, ILS_MKR.csv, and ILS_RMK.csv
class CSVILSParser: CSVParser {
  var csvDirectory = URL(fileURLWithPath: "/")
  var ILSFacilities = [ILSKey: ILS]()

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
    // Parse ILS_BASE.csv first for base ILS data
    // Headers: EFF_DATE,SITE_NO,SITE_TYPE_CODE,STATE_CODE,ARPT_ID,CITY,COUNTRY_CODE,RWY_END_ID,
    //          ILS_LOC_ID,SYSTEM_TYPE_CODE,STATE_NAME,REGION_CODE,RWY_LEN,RWY_WIDTH,CATEGORY,
    //          OWNER,OPERATOR,APCH_BEAR,MAG_VAR,MAG_VAR_HEMIS,COMPONENT_STATUS,COMPONENT_STATUS_DATE,
    //          LAT_DEG,LAT_MIN,LAT_SEC,LAT_HEMIS,LAT_DECIMAL,LONG_DEG,LONG_MIN,LONG_SEC,LONG_HEMIS,
    //          LONG_DECIMAL,LAT_LONG_SOURCE_CODE,SITE_ELEVATION,LOC_FREQ,BK_COURSE_STATUS_CODE
    try await parseCSVFile(filename: "ILS_BASE.csv", expectedFieldCount: 36) { fields in
      guard fields.count >= 32 else {
        throw ParserError.truncatedRecord(
          recordType: "ILS_BASE",
          expectedMinLength: 32,
          actualLength: fields.count
        )
      }

      let siteNo = fields[1].trimmingCharacters(in: .whitespaces)
      let runwayEndId = fields[7].trimmingCharacters(in: .whitespaces)
      let systemTypeCode = fields[9].trimmingCharacters(in: .whitespaces)
      let systemType = parseSystemType(systemTypeCode)

      let key = ILSKey(
        airportSiteNumber: siteNo,
        runwayEndId: runwayEndId,
        systemType: systemType
      )

      // Parse effective date
      let effDate = self.parseYYYYMMDDDate(fields[0])

      // Parse position (convert decimal degrees to arc-seconds)
      let latDecimal = Float(fields[26].trimmingCharacters(in: .whitespaces))
      let lonDecimal = Float(fields[31].trimmingCharacters(in: .whitespaces))

      // Parse magnetic variation (W = negative, E = positive)
      let magVar: Int? = {
        let magVarValue = fields.count > 18 ? fields[18].trimmingCharacters(in: .whitespaces) : ""
        let magVarHemis = fields.count > 19 ? fields[19].trimmingCharacters(in: .whitespaces) : ""
        guard !magVarValue.isEmpty, let value = Int(magVarValue) else { return nil }
        return magVarHemis == "W" ? -value : value
      }()

      // Convert approach bearing to Bearing<Float>
      let approachBearing = self.parseOptionalFloat(fields, index: 17).map { value in
        Bearing(value, reference: .magnetic, magneticVariation: magVar ?? 0)
      }

      // Create base ILS
      var ils = ILS(
        airportSiteNumber: siteNo,
        runwayEndId: runwayEndId,
        systemType: systemType,
        ILSId: fields[8].trimmingCharacters(in: .whitespaces),
        airportId: fields[4].trimmingCharacters(in: .whitespaces),
        airportName: "",  // Not directly in CSV BASE, but could be derived
        city: fields[5].trimmingCharacters(in: .whitespaces),
        stateCode: fields[3].trimmingCharacters(in: .whitespaces),
        stateName: fields.count > 10 ? fields[10].trimmingCharacters(in: .whitespaces) : nil,
        regionCode: fields.count > 11 ? fields[11].trimmingCharacters(in: .whitespaces) : nil,
        runwayLength: self.parseOptionalUInt(fields, index: 12),
        runwayWidth: self.parseOptionalUInt(fields, index: 13),
        category: self.parseCategory(fields.count > 14 ? fields[14] : ""),
        owner: fields.count > 15 ? fields[15].trimmingCharacters(in: .whitespaces) : nil,
        operator: fields.count > 16 ? fields[16].trimmingCharacters(in: .whitespaces) : nil,
        approachBearing: approachBearing,
        magneticVariation: magVar,
        effectiveDate: effDate
      )

      // Create localizer from BASE file
      let LOCStatus = self.parseOperationalStatus(
        fields.count > 20 ? fields[20] : ""
      )
      let LOCStatusDate = self.parseYYYYMMDDDate(fields.count > 21 ? fields[21] : "")
      let LOCFreq = self.parseMHzToKHz(fields, index: 34)
      let backCourse = self.parseBackCourseStatus(fields.count > 35 ? fields[35] : "")
      let posSource = self.parsePositionSource(fields.count > 32 ? fields[32] : "")
      let siteElev = self.parseOptionalFloat(fields, index: 33)

      guard
        let LOCPosition = try self.makeLocation(
          latitude: latDecimal,
          longitude: lonDecimal,
          elevation: siteElev,
          context: "ILS \(siteNo) localizer"
        )
      else {
        throw ParserError.missingRequiredField(field: "position", recordType: "ILS_BASE")
      }

      ils.localizer = ILS.Localizer(
        status: LOCStatus,
        statusDate: LOCStatusDate,
        position: LOCPosition,
        positionSource: posSource,
        distanceFromApproachEnd: nil,
        distanceFromCenterline: nil,
        distanceSource: nil,
        frequency: LOCFreq,
        backCourseStatus: backCourse,
        courseWidth: nil,
        courseWidthAtThreshold: nil,
        distanceFromStopEnd: nil,
        directionFromStopEnd: nil,
        serviceCode: nil
      )

      self.ILSFacilities[key] = ils
    }

    // Parse ILS_GS.csv for glide slope data
    // Headers: EFF_DATE,SITE_NO,SITE_TYPE_CODE,STATE_CODE,ARPT_ID,CITY,COUNTRY_CODE,RWY_END_ID,
    //          ILS_LOC_ID,SYSTEM_TYPE_CODE,COMPONENT_STATUS,COMPONENT_STATUS_DATE,LAT_DEG,LAT_MIN,
    //          LAT_SEC,LAT_HEMIS,LAT_DECIMAL,LONG_DEG,LONG_MIN,LONG_SEC,LONG_HEMIS,LONG_DECIMAL,
    //          LAT_LONG_SOURCE_CODE,SITE_ELEVATION,G_S_TYPE_CODE,G_S_ANGLE,G_S_FREQ
    try await parseCSVFile(filename: "ILS_GS.csv", expectedFieldCount: 27) { fields in
      guard fields.count >= 25 else {
        throw ParserError.truncatedRecord(
          recordType: "ILS_GS",
          expectedMinLength: 25,
          actualLength: fields.count
        )
      }

      let siteNo = fields[1].trimmingCharacters(in: .whitespaces)
      let runwayEndId = fields[7].trimmingCharacters(in: .whitespaces)
      let systemTypeCode = fields[9].trimmingCharacters(in: .whitespaces)
      let systemType = self.parseSystemType(systemTypeCode)

      let key = ILSKey(
        airportSiteNumber: siteNo,
        runwayEndId: runwayEndId,
        systemType: systemType
      )

      guard self.ILSFacilities[key] != nil else {
        throw ParserError.unknownParentRecord(
          parentType: "ILS",
          parentID: "\(siteNo)-\(runwayEndId)",
          childType: "glide slope"
        )
      }

      let latDecimal = Float(fields[16].trimmingCharacters(in: .whitespaces))
      let lonDecimal = Float(fields[21].trimmingCharacters(in: .whitespaces))

      let gsElev = self.parseOptionalFloat(fields, index: 23)
      guard
        let gsPosition = try self.makeLocation(
          latitude: latDecimal,
          longitude: lonDecimal,
          elevation: gsElev,
          context: "ILS \(siteNo) glide slope"
        )
      else {
        throw ParserError.missingRequiredField(field: "position", recordType: "ILS_GS")
      }

      let glideSlope = ILS.GlideSlope(
        status: self.parseOperationalStatus(fields[10]),
        statusDate: self.parseYYYYMMDDDate(fields[11]),
        position: gsPosition,
        positionSource: self.parsePositionSource(fields[22]),
        distanceFromApproachEnd: nil,
        distanceFromCenterline: nil,
        distanceSource: nil,
        glideSlopeType: self.parseGlidePathType(fields[24]),
        angle: self.parseOptionalFloat(fields, index: 25),
        frequency: self.parseMHzToKHz(fields, index: 26),
        adjacentRunwayElevation: nil
      )

      self.ILSFacilities[key]?.glideSlope = glideSlope
    }

    // Parse ILS_DME.csv for DME data
    // Headers: EFF_DATE,SITE_NO,SITE_TYPE_CODE,STATE_CODE,ARPT_ID,CITY,COUNTRY_CODE,RWY_END_ID,
    //          ILS_LOC_ID,SYSTEM_TYPE_CODE,COMPONENT_STATUS,COMPONENT_STATUS_DATE,LAT_DEG,LAT_MIN,
    //          LAT_SEC,LAT_HEMIS,LAT_DECIMAL,LONG_DEG,LONG_MIN,LONG_SEC,LONG_HEMIS,LONG_DECIMAL,
    //          LAT_LONG_SOURCE_CODE,SITE_ELEVATION,CHANNEL
    try await parseCSVFile(filename: "ILS_DME.csv", expectedFieldCount: 25) { fields in
      guard fields.count >= 24 else {
        throw ParserError.truncatedRecord(
          recordType: "ILS_DME",
          expectedMinLength: 24,
          actualLength: fields.count
        )
      }

      let siteNo = fields[1].trimmingCharacters(in: .whitespaces)
      let runwayEndId = fields[7].trimmingCharacters(in: .whitespaces)
      let systemTypeCode = fields[9].trimmingCharacters(in: .whitespaces)
      let systemType = self.parseSystemType(systemTypeCode)

      let key = ILSKey(
        airportSiteNumber: siteNo,
        runwayEndId: runwayEndId,
        systemType: systemType
      )

      guard self.ILSFacilities[key] != nil else {
        throw ParserError.unknownParentRecord(
          parentType: "ILS",
          parentID: "\(siteNo)-\(runwayEndId)",
          childType: "DME"
        )
      }

      let latDecimal = Float(fields[16].trimmingCharacters(in: .whitespaces))
      let lonDecimal = Float(fields[21].trimmingCharacters(in: .whitespaces))

      let DMEElev = self.parseOptionalFloat(fields, index: 23)
      guard
        let DMEPosition = try self.makeLocation(
          latitude: latDecimal,
          longitude: lonDecimal,
          elevation: DMEElev,
          context: "ILS \(siteNo) DME"
        )
      else {
        throw ParserError.missingRequiredField(field: "position", recordType: "ILS_DME")
      }

      let DME = ILS.DME(
        status: self.parseOperationalStatus(fields[10]),
        statusDate: self.parseYYYYMMDDDate(fields[11]),
        position: DMEPosition,
        positionSource: self.parsePositionSource(fields[22]),
        distanceFromApproachEnd: nil,
        distanceFromCenterline: nil,
        distanceSource: nil,
        channel: fields[24].trimmingCharacters(in: .whitespaces),
        distanceFromStopEnd: nil
      )

      self.ILSFacilities[key]?.dme = DME
    }

    // Parse ILS_MKR.csv for marker beacon data
    // Headers: EFF_DATE,SITE_NO,SITE_TYPE_CODE,STATE_CODE,ARPT_ID,CITY,COUNTRY_CODE,RWY_END_ID,
    //          ILS_LOC_ID,SYSTEM_TYPE_CODE,ILS_COMP_TYPE_CODE,COMPONENT_STATUS,COMPONENT_STATUS_DATE,
    //          LAT_DEG,LAT_MIN,LAT_SEC,LAT_HEMIS,LAT_DECIMAL,LONG_DEG,LONG_MIN,LONG_SEC,LONG_HEMIS,
    //          LONG_DECIMAL,LAT_LONG_SOURCE_CODE,SITE_ELEVATION,MKR_FAC_TYPE_CODE,MARKER_ID_BEACON,
    //          COMPASS_LOCATOR_NAME,FREQ,NAV_ID,NAV_TYPE,LOW_POWERED_NDB_STATUS
    try await parseCSVFile(filename: "ILS_MKR.csv", expectedFieldCount: 32) { fields in
      guard fields.count >= 26 else {
        throw ParserError.truncatedRecord(
          recordType: "ILS_MKR",
          expectedMinLength: 26,
          actualLength: fields.count
        )
      }

      let siteNo = fields[1].trimmingCharacters(in: .whitespaces)
      let runwayEndId = fields[7].trimmingCharacters(in: .whitespaces)
      let systemTypeCode = fields[9].trimmingCharacters(in: .whitespaces)
      let systemType = self.parseSystemType(systemTypeCode)

      let key = ILSKey(
        airportSiteNumber: siteNo,
        runwayEndId: runwayEndId,
        systemType: systemType
      )

      guard self.ILSFacilities[key] != nil else {
        throw ParserError.unknownParentRecord(
          parentType: "ILS",
          parentID: "\(siteNo)-\(runwayEndId)",
          childType: "marker beacon"
        )
      }

      let markerTypeCode = fields[10].trimmingCharacters(in: .whitespaces)
      guard let markerType = self.parseMarkerType(markerTypeCode) else {
        throw ParserError.unknownRecordEnumValue(markerTypeCode)
      }

      let latDecimal = Float(fields[17].trimmingCharacters(in: .whitespaces))
      let lonDecimal = Float(fields[22].trimmingCharacters(in: .whitespaces))

      // Parse collocated navaid
      var collocatedNavaid: String?
      let navId = fields.count > 29 ? fields[29].trimmingCharacters(in: .whitespaces) : ""
      let navType = fields.count > 30 ? fields[30].trimmingCharacters(in: .whitespaces) : ""
      if !navId.isEmpty && !navType.isEmpty {
        collocatedNavaid = "\(navId)*\(navType)"
      }

      let mkrElev = self.parseOptionalFloat(fields, index: 24)
      guard
        let mkrPosition = try self.makeLocation(
          latitude: latDecimal,
          longitude: lonDecimal,
          elevation: mkrElev,
          context: "ILS \(siteNo) marker beacon"
        )
      else {
        throw ParserError.missingRequiredField(field: "position", recordType: "ILS_MKR")
      }

      let marker = ILS.MarkerBeacon(
        markerType: markerType,
        status: self.parseOperationalStatus(fields[11]),
        statusDate: self.parseYYYYMMDDDate(fields[12]),
        position: mkrPosition,
        positionSource: self.parsePositionSource(fields[23]),
        distanceFromApproachEnd: nil,
        distanceFromCenterline: nil,
        distanceSource: nil,
        facilityType: self.parseMarkerFacilityType(fields[25]),
        locationId: fields.count > 26 ? fields[26].trimmingCharacters(in: .whitespaces) : nil,
        name: fields.count > 27 ? fields[27].trimmingCharacters(in: .whitespaces) : nil,
        frequency: self.parseOptionalUInt(fields, index: 28),
        collocatedNavaid: collocatedNavaid,
        lowPoweredNDBStatus: fields.count > 31
          ? self.parseOperationalStatus(fields[31]) : nil,
        service: nil
      )

      self.ILSFacilities[key]?.markers.append(marker)
    }

    // Parse ILS_RMK.csv for remarks
    // Headers: EFF_DATE,SITE_NO,SITE_TYPE_CODE,STATE_CODE,ARPT_ID,CITY,COUNTRY_CODE,RWY_END_ID,
    //          ILS_LOC_ID,SYSTEM_TYPE_CODE,TAB_NAME,ILS_COMP_TYPE_CODE,REF_COL_NAME,REF_COL_SEQ_NO,REMARK
    try await parseCSVFile(filename: "ILS_RMK.csv", expectedFieldCount: 15) { fields in
      guard fields.count >= 15 else {
        throw ParserError.truncatedRecord(
          recordType: "ILS_RMK",
          expectedMinLength: 15,
          actualLength: fields.count
        )
      }

      let siteNo = fields[1].trimmingCharacters(in: .whitespaces)
      let runwayEndId = fields[7].trimmingCharacters(in: .whitespaces)
      let systemTypeCode = fields[9].trimmingCharacters(in: .whitespaces)
      let systemType = self.parseSystemType(systemTypeCode)

      let key = ILSKey(
        airportSiteNumber: siteNo,
        runwayEndId: runwayEndId,
        systemType: systemType
      )

      guard self.ILSFacilities[key] != nil else {
        throw ParserError.unknownParentRecord(
          parentType: "ILS",
          parentID: "\(siteNo)-\(runwayEndId)",
          childType: "remark"
        )
      }

      let remark = fields[14].trimmingCharacters(in: .whitespaces)
      if !remark.isEmpty {
        self.ILSFacilities[key]?.remarks.append(remark)
      }
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(ILSFacilities: Array(ILSFacilities.values))
  }

  // MARK: - Helper methods

  private func parseOptionalUInt(_ fields: [String], index: Int) -> UInt? {
    guard index < fields.count else { return nil }
    let value = fields[index].trimmingCharacters(in: .whitespaces)
    return value.isEmpty ? nil : UInt(value)
  }

  private func parseOptionalFloat(_ fields: [String], index: Int) -> Float? {
    guard index < fields.count else { return nil }
    let value = fields[index].trimmingCharacters(in: .whitespaces)
    return value.isEmpty ? nil : Float(value)
  }

  private func parseMHzToKHz(_ fields: [String], index: Int) -> UInt? {
    guard let mhz = parseOptionalFloat(fields, index: index) else { return nil }
    return UInt(mhz * 1000)
  }

  private func parseYYYYMMDDDate(_ string: String) -> DateComponents? {
    let trimmed = string.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    // Format: YYYY/MM/DD
    let parts = trimmed.split(separator: "/")
    guard parts.count == 3,
      let year = Int(parts[0]),
      let month = Int(parts[1]),
      let day = Int(parts[2])
    else { return nil }

    return DateComponents(year: year, month: month, day: day)
  }

  private func parseSystemType(_ code: String) -> ILS.SystemType {
    let trimmed = code.trimmingCharacters(in: .whitespaces)
    return ILS.SystemType.for(trimmed) ?? .ILS
  }

  private func parseCategory(_ code: String) -> ILS.Category? {
    let trimmed = code.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    return ILS.Category.for(trimmed)
  }

  private func parseOperationalStatus(_ status: String) -> OperationalStatus? {
    let trimmed = status.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    return OperationalStatus.for(trimmed)
  }

  private func parsePositionSource(_ code: String) -> ILS.PositionSource? {
    let trimmed = code.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    return ILS.PositionSource.for(trimmed)
  }

  private func parseBackCourseStatus(_ code: String) -> ILS.BackCourseStatus? {
    let trimmed = code.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    return ILS.BackCourseStatus.for(trimmed)
  }

  private func parseGlidePathType(_ code: String) -> ILS.GlideSlope.GlidePathType? {
    let trimmed = code.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    return ILS.GlideSlope.GlidePathType.for(trimmed)
  }

  private func parseMarkerType(_ code: String) -> ILS.MarkerBeacon.MarkerType? {
    let trimmed = code.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    return ILS.MarkerBeacon.MarkerType.for(trimmed)
  }

  private func parseMarkerFacilityType(_ code: String) -> ILS.MarkerBeacon.MarkerFacilityType? {
    let trimmed = code.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    // Handle short codes from CSV
    switch trimmed {
      case "M": return .marker
      case "MR": return .markerNDB
      case "CL", "COMLO": return .compassLocator
      case "MC": return .markerCompassLocator
      case "MN": return .markerNDB
      default: return ILS.MarkerBeacon.MarkerFacilityType.for(trimmed)
    }
  }

  /// Creates a Location from optional lat/lon (decimal degrees), throwing if only one is present.
  /// Converts decimal degrees to arc-seconds for Location storage.
  private func makeLocation(
    latitude: Float?,
    longitude: Float?,
    elevation: Float?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        // Convert decimal degrees to arc-seconds (multiply by 3600)
        return Location(latitude: lat * 3600, longitude: lon * 3600, elevation: elevation)
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
