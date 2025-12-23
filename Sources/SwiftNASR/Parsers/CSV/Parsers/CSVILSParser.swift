import Foundation

/// CSV ILS Parser for parsing ILS_BASE.csv, ILS_GS.csv, ILS_DME.csv, ILS_MKR.csv, and ILS_RMK.csv
actor CSVILSParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["ILS_BASE.csv", "ILS_GS.csv", "ILS_DME.csv", "ILS_MKR.csv", "ILS_RMK.csv"]

  var ILSFacilities = [ILSKey: ILS]()

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse ILS_BASE.csv first for base ILS data
    try await parseCSVFile(
      filename: "ILS_BASE.csv",
      requiredColumns: ["SITE_NO", "RWY_END_ID", "SYSTEM_TYPE_CODE", "LAT_DECIMAL", "LONG_DECIMAL"]
    ) { row in
      let siteNo = try row["SITE_NO"]
      let runwayEndId = try row["RWY_END_ID"]
      let systemType = try parseSystemType(try row["SYSTEM_TYPE_CODE"])

      let key = ILSKey(
        airportSiteNumber: siteNo,
        runwayEndId: runwayEndId,
        systemType: systemType
      )

      // Parse position (convert decimal degrees to arc-seconds)
      let latDecimal = Float(try row["LAT_DECIMAL"])
      let lonDecimal = Float(try row["LONG_DECIMAL"])

      // Parse magnetic variation (W = negative, E = positive)
      let magVar: Int? = {
        guard let magVarValue = row[ifExists: "MAG_VAR"],
          let value = Int(magVarValue)
        else { return nil }
        let magVarHemis = row[ifExists: "MAG_VAR_HEMIS"] ?? ""
        return magVarHemis == "W" ? -value : value
      }()

      // Convert approach bearing to Bearing<Float>
      let approachBearing: Bearing<Float>? =
        if let bearStr = row[ifExists: "APCH_BEAR"],
          let value = Float(bearStr)
        {
          Bearing(value, reference: .magnetic, magneticVariationDeg: magVar ?? 0)
        } else {
          nil
        }

      // Create base ILS
      var ils = ILS(
        airportSiteNumber: siteNo,
        runwayEndId: runwayEndId,
        systemType: systemType,
        ILSId: try row["ILS_LOC_ID"],
        airportId: try row["ARPT_ID"],
        airportName: "",  // Not directly in CSV BASE
        city: try row["CITY"],
        stateCode: try row["STATE_CODE"],
        stateName: row[ifExists: "STATE_NAME"],
        regionCode: row[ifExists: "REGION_CODE"],
        runwayLengthFt: row[ifExists: "RWY_LEN"].flatMap { UInt($0) },
        runwayWidthFt: row[ifExists: "RWY_WIDTH"].flatMap { UInt($0) },
        category: self.parseCategory(row[ifExists: "CATEGORY"]),
        owner: row[ifExists: "OWNER"],
        operator: row[ifExists: "OPERATOR"],
        approachBearing: approachBearing,
        magneticVariationDeg: magVar,
        effectiveDateComponents: self.parseYYYYMMDDDate(row[ifExists: "EFF_DATE"])
      )

      // Create localizer from BASE file
      let LOCStatus = self.parseOperationalStatus(row[ifExists: "COMPONENT_STATUS"])
      let LOCStatusDate = self.parseYYYYMMDDDate(row[ifExists: "COMPONENT_STATUS_DATE"])
      let LOCFreq = row[ifExists: "LOC_FREQ"].flatMap { Float($0) }.map { UInt($0 * 1000) }
      let backCourse = self.parseBackCourseStatus(row[ifExists: "BK_COURSE_STATUS_CODE"])
      let posSource = self.parsePositionSource(row[ifExists: "LAT_LONG_SOURCE_CODE"])
      let siteElev = row[ifExists: "SITE_ELEVATION"].flatMap { Float($0) }

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
        statusDateComponents: LOCStatusDate,
        position: LOCPosition,
        positionSource: posSource,
        distanceFromApproachEndFt: nil,
        distanceFromCenterlineFt: nil,
        distanceSource: nil,
        frequencyKHz: LOCFreq,
        backCourseStatus: backCourse,
        courseWidthDeg: nil,
        courseWidthAtThresholdDeg: nil,
        distanceFromStopEndFt: nil,
        directionFromStopEnd: nil,
        serviceCode: nil
      )

      self.ILSFacilities[key] = ils
    }

    // Parse ILS_GS.csv for glide slope data
    try await parseCSVFile(
      filename: "ILS_GS.csv",
      requiredColumns: ["SITE_NO", "RWY_END_ID", "SYSTEM_TYPE_CODE", "LAT_DECIMAL", "LONG_DECIMAL"]
    ) { row in
      let siteNo = try row["SITE_NO"]
      let runwayEndId = try row["RWY_END_ID"]
      let systemType = try self.parseSystemType(try row["SYSTEM_TYPE_CODE"])

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

      let latDecimal = Float(try row["LAT_DECIMAL"])
      let lonDecimal = Float(try row["LONG_DECIMAL"])

      let gsElev = row[ifExists: "SITE_ELEVATION"].flatMap { Float($0) }
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
        status: self.parseOperationalStatus(row[ifExists: "COMPONENT_STATUS"]),
        statusDateComponents: self.parseYYYYMMDDDate(row[ifExists: "COMPONENT_STATUS_DATE"]),
        position: gsPosition,
        positionSource: self.parsePositionSource(row[ifExists: "LAT_LONG_SOURCE_CODE"]),
        distanceFromApproachEndFt: nil,
        distanceFromCenterlineFt: nil,
        distanceSource: nil,
        glideSlopeType: self.parseGlidePathType(row[ifExists: "G_S_TYPE_CODE"]),
        angleDeg: row[ifExists: "G_S_ANGLE"].flatMap { Float($0) },
        frequencyKHz: row[ifExists: "G_S_FREQ"].flatMap { Float($0) }.map { UInt($0 * 1000) },
        adjacentRunwayElevationFtMSL: nil
      )

      self.ILSFacilities[key]?.glideSlope = glideSlope
    }

    // Parse ILS_DME.csv for DME data
    try await parseCSVFile(
      filename: "ILS_DME.csv",
      requiredColumns: ["SITE_NO", "RWY_END_ID", "SYSTEM_TYPE_CODE", "LAT_DECIMAL", "LONG_DECIMAL"]
    ) { row in
      let siteNo = try row["SITE_NO"]
      let runwayEndId = try row["RWY_END_ID"]
      let systemType = try self.parseSystemType(try row["SYSTEM_TYPE_CODE"])

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

      let latDecimal = Float(try row["LAT_DECIMAL"])
      let lonDecimal = Float(try row["LONG_DECIMAL"])

      let DMEElev = row[ifExists: "SITE_ELEVATION"].flatMap { Float($0) }
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
        status: self.parseOperationalStatus(row[ifExists: "COMPONENT_STATUS"]),
        statusDateComponents: self.parseYYYYMMDDDate(row[ifExists: "COMPONENT_STATUS_DATE"]),
        position: DMEPosition,
        positionSource: self.parsePositionSource(row[ifExists: "LAT_LONG_SOURCE_CODE"]),
        distanceFromApproachEndFt: nil,
        distanceFromCenterlineFt: nil,
        distanceSource: nil,
        channel: row[ifExists: "CHANNEL"] ?? "",
        distanceFromStopEndFt: nil
      )

      self.ILSFacilities[key]?.dme = DME
    }

    // Parse ILS_MKR.csv for marker beacon data
    try await parseCSVFile(
      filename: "ILS_MKR.csv",
      requiredColumns: [
        "SITE_NO", "RWY_END_ID", "SYSTEM_TYPE_CODE", "ILS_COMP_TYPE_CODE",
        "LAT_DECIMAL", "LONG_DECIMAL"
      ]
    ) { row in
      let siteNo = try row["SITE_NO"]
      let runwayEndId = try row["RWY_END_ID"]
      let systemType = try self.parseSystemType(try row["SYSTEM_TYPE_CODE"])

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

      guard let markerType = self.parseMarkerType(try row["ILS_COMP_TYPE_CODE"]) else {
        throw ParserError.unknownRecordEnumValue(try row["ILS_COMP_TYPE_CODE"])
      }

      let latDecimal = Float(try row["LAT_DECIMAL"])
      let lonDecimal = Float(try row["LONG_DECIMAL"])

      // Parse collocated navaid
      var collocatedNavaid: String?
      let navId = row[ifExists: "NAV_ID"] ?? ""
      let navType = row[ifExists: "NAV_TYPE"] ?? ""
      if !navId.isEmpty && !navType.isEmpty {
        collocatedNavaid = "\(navId)*\(navType)"
      }

      let mkrElev = row[ifExists: "SITE_ELEVATION"].flatMap { Float($0) }
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
        status: self.parseOperationalStatus(row[ifExists: "COMPONENT_STATUS"]),
        statusDateComponents: self.parseYYYYMMDDDate(row[ifExists: "COMPONENT_STATUS_DATE"]),
        position: mkrPosition,
        positionSource: self.parsePositionSource(row[ifExists: "LAT_LONG_SOURCE_CODE"]),
        distanceFromApproachEndFt: nil,
        distanceFromCenterlineFt: nil,
        distanceSource: nil,
        facilityType: self.parseMarkerFacilityType(row[ifExists: "MKR_FAC_TYPE_CODE"]),
        locationId: row[ifExists: "MARKER_ID_BEACON"],
        name: row[ifExists: "COMPASS_LOCATOR_NAME"],
        frequencyKHz: row[ifExists: "FREQ"].flatMap { UInt($0) },
        collocatedNavaid: collocatedNavaid,
        lowPoweredNDBStatus: self.parseOperationalStatus(row[ifExists: "LOW_POWERED_NDB_STATUS"]),
        service: nil
      )

      self.ILSFacilities[key]?.markers.append(marker)
    }

    // Parse ILS_RMK.csv for remarks
    try await parseCSVFile(
      filename: "ILS_RMK.csv",
      requiredColumns: ["SITE_NO", "RWY_END_ID", "SYSTEM_TYPE_CODE", "REMARK"]
    ) { row in
      let siteNo = try row["SITE_NO"]
      let runwayEndId = try row["RWY_END_ID"]
      let systemType = try self.parseSystemType(try row["SYSTEM_TYPE_CODE"])

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

      let remark = try row["REMARK"]
      if !remark.isEmpty {
        self.ILSFacilities[key]?.remarks.append(remark)
      }
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(ILSFacilities: Array(ILSFacilities.values))
  }

  // MARK: - Helper methods

  private func parseYYYYMMDDDate(_ string: String?) -> DateComponents? {
    guard let trimmed = string, !trimmed.isEmpty else { return nil }

    // Format: YYYY/MM/DD
    let parts = trimmed.split(separator: "/")
    guard parts.count == 3,
      let year = Int(parts[0]),
      let month = Int(parts[1]),
      let day = Int(parts[2])
    else { return nil }

    return DateComponents(year: year, month: month, day: day)
  }

  private func parseSystemType(_ code: String) throws -> ILS.SystemType {
    guard let systemType = ILS.SystemType.for(code) else {
      throw ParserError.unknownRecordEnumValue(code)
    }
    return systemType
  }

  private func parseCategory(_ code: String?) -> ILS.Category? {
    guard let trimmed = code, !trimmed.isEmpty else { return nil }
    return ILS.Category.for(trimmed)
  }

  private func parseOperationalStatus(_ status: String?) -> OperationalStatus? {
    guard let trimmed = status, !trimmed.isEmpty else { return nil }
    return OperationalStatus.for(trimmed)
  }

  private func parsePositionSource(_ code: String?) -> ILS.PositionSource? {
    guard let trimmed = code, !trimmed.isEmpty else { return nil }
    return ILS.PositionSource.for(trimmed)
  }

  private func parseBackCourseStatus(_ code: String?) -> ILS.BackCourseStatus? {
    guard let trimmed = code, !trimmed.isEmpty else { return nil }
    return ILS.BackCourseStatus.for(trimmed)
  }

  private func parseGlidePathType(_ code: String?) -> ILS.GlideSlope.GlidePathType? {
    guard let trimmed = code, !trimmed.isEmpty else { return nil }
    return ILS.GlideSlope.GlidePathType.for(trimmed)
  }

  private func parseMarkerType(_ code: String?) -> ILS.MarkerBeacon.MarkerType? {
    guard let trimmed = code, !trimmed.isEmpty else { return nil }
    return ILS.MarkerBeacon.MarkerType.for(trimmed)
  }

  private func parseMarkerFacilityType(_ code: String?) -> ILS.MarkerBeacon.MarkerFacilityType? {
    guard let trimmed = code, !trimmed.isEmpty else { return nil }
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
        return Location(
          latitudeArcsec: lat * 3600,
          longitudeArcsec: lon * 3600,
          elevationFtMSL: elevation
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
