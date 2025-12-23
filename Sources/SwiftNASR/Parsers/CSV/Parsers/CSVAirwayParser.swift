import Foundation
import StreamingCSV

/// CSV Airway Parser for parsing AWY_BASE.csv and AWY_SEG_ALT.csv
actor CSVAirwayParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["AWY_BASE.csv", "AWY_SEG_ALT.csv"]

  var airways = [AirwayKey: Airway]()
  var segments = [SegmentKey: Airway.Segment]()

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // First parse AWY_BASE.csv for airway definitions and remarks
    try await parseCSVFile(
      filename: "AWY_BASE.csv",
      requiredColumns: ["AWY_LOCATION", "AWY_ID"]
    ) { row in
      let location = try row["AWY_LOCATION"]
      let designation = try row["AWY_ID"]
      let remark = row[ifExists: "REMARK"] ?? ""

      // Determine type from location code.
      // Per awy_rf.txt layout: "A" = Alaska, "H" = Hawaii, "BLANK" = U.S. Federal Airway
      let type: Airway.AirwayType
      switch location {
        case "A": type = .alaska
        case "H": type = .hawaii
        default: type = .federal  // Documented default per layout file
      }

      let airwayKey = AirwayKey(designation: designation, type: type)

      if self.airways[airwayKey] == nil {
        self.airways[airwayKey] = Airway(designation: designation, type: type)
      }

      if !remark.isEmpty {
        self.airways[airwayKey]?.remarks.append(remark)
      }
    }

    // Then parse AWY_SEG_ALT.csv for segment data
    try await parseCSVFile(
      filename: "AWY_SEG_ALT.csv",
      requiredColumns: ["AWY_LOCATION", "AWY_ID", "POINT_SEQ", "FROM_POINT"]
    ) { row in
      let location = try row["AWY_LOCATION"]
      let designation = try row["AWY_ID"]
      let seqStr = try row["POINT_SEQ"]
      guard let sequenceNumber = UInt(seqStr) else {
        throw ParserError.missingRequiredField(field: "sequenceNumber", recordType: "AWY_SEG_ALT")
      }

      // Per awy_rf.txt layout: "A" = Alaska, "H" = Hawaii, "BLANK" = U.S. Federal Airway
      let type: Airway.AirwayType
      switch location {
        case "A": type = .alaska
        case "H": type = .hawaii
        default: type = .federal  // Documented default per layout file
      }

      let airwayKey = AirwayKey(designation: designation, type: type)
      let segmentKey = SegmentKey(airwayKey: airwayKey, sequenceNumber: sequenceNumber)

      // Create airway if it doesn't exist
      if self.airways[airwayKey] == nil {
        self.airways[airwayKey] = Airway(designation: designation, type: type)
      }

      // Parse point data
      let fromPoint = try row["FROM_POINT"]
      let pointTypeStr = row[ifExists: "FROM_PT_TYPE"] ?? ""
      let pointType = Airway.PointType(rawValue: pointTypeStr)
      let stateCode = row[ifExists: "STATE_CODE"]
      let ICAORegion = row[ifExists: "ICAO_REGION_CODE"]
      let ARTCCID = row[ifExists: "ARTCC"]

      let point = Airway.Point(
        sequenceNumber: sequenceNumber,
        name: fromPoint.isEmpty ? nil : fromPoint,
        pointType: pointType,
        position: nil,  // Not in CSV
        stateCode: stateCode?.isEmpty == true ? nil : stateCode,
        ICAORegionCode: ICAORegion?.isEmpty == true ? nil : ICAORegion,
        navaidId: nil,
        minimumReceptionAltitudeFt: self.parseOptionalUInt(row, column: "MIN_RECEP_ALT")
      )

      // Parse changeover point if present
      var changeoverPoint: Airway.ChangeoverPoint?
      let chgovrPtName = row[ifExists: "CHGOVR_PT_NAME"] ?? ""
      if !chgovrPtName.isEmpty {
        changeoverPoint = Airway.ChangeoverPoint(
          distanceNM: self.parseOptionalUInt(row, column: "CHGOVR_PT_DIST"),
          navaidName: chgovrPtName,
          navaidType: nil,
          position: nil,
          stateCode: nil
        )
      }

      // Parse altitudes
      let altitudes = try Airway.SegmentAltitudes(
        MEAFt: self.parseOptionalUInt(row, column: "MIN_ENROUTE_ALT"),
        MEADirection: self.parseBoundDirection(row, column: "MIN_ENROUTE_ALT_DIR"),
        MEAOppositeFt: self.parseOptionalUInt(row, column: "MIN_ENROUTE_ALT_OPPOSITE"),
        MEAOppositeDirection: self.parseBoundDirection(row, column: "MIN_ENROUTE_ALT_OPPOSITE_DIR"),
        MAAFt: self.parseOptionalUInt(row, column: "MAX_AUTH_ALT"),
        MOCAFt: self.parseOptionalUInt(row, column: "MIN_OBSTN_CLNC_ALT"),
        MCAFt: self.parseOptionalUInt(row, column: "MIN_CROSS_ALT"),
        MCADirection: self.parseBoundDirection(row, column: "MIN_CROSS_ALT_DIR"),
        MCAOppositeFt: self.parseOptionalUInt(row, column: "MIN_CROSS_ALT_OPPOSITE"),
        MCAOppositeDirection: self.parseBoundDirection(row, column: "MIN_CROSS_ALT_OPPOSITE_DIR"),
        GNSS_MEAFt: self.parseOptionalUInt(row, column: "GPS_MIN_ENROUTE_ALT"),
        GNSS_MEADirection: self.parseBoundDirection(row, column: "GPS_MIN_ENROUTE_ALT_DIR"),
        GNSS_MEAOppositeFt: self.parseOptionalUInt(row, column: "GPS_MIN_ENROUTE_ALT_OPPOSITE"),
        GNSS_MEAOppositeDirection: self.parseBoundDirection(row, column: "GPS_MEA_OPPOSITE_DIR"),
        DME_MEAFt: self.parseOptionalUInt(row, column: "DD_IRU_MEA"),
        DME_MEADirection: self.parseBoundDirection(row, column: "DD_IRU_MEA_DIR"),
        DME_MEAOppositeFt: self.parseOptionalUInt(row, column: "DD_I_MEA_OPPOSITE"),
        DME_MEAOppositeDirection: self.parseBoundDirection(row, column: "DD_I_MEA_OPPOSITE_DIR")
      )

      // Parse segment flags
      let isAirwayGap =
        try ParserHelpers.parseYNFlag(
          row[ifExists: "AWY_SEG_GAP_FLAG"],
          fieldName: "AWY_SEG_GAP_FLAG"
        ) ?? false
      let hasSignalCoverageGap =
        try ParserHelpers.parseYNFlag(
          row[ifExists: "SIGNAL_GAP_FLAG"],
          fieldName: "SIGNAL_GAP_FLAG"
        ) ?? false
      let isDogleg =
        try ParserHelpers.parseYNFlag(row[ifExists: "DOGLEG"], fieldName: "DOGLEG") ?? false

      let segment = Airway.Segment(
        sequenceNumber: sequenceNumber,
        point: point,
        changeoverPoint: changeoverPoint,
        altitudes: altitudes,
        distanceToNextNM: self.parseOptionalFloat(row, column: "MAG_COURSE_DIST"),
        magneticCourseDeg: self.parseOptionalFloat(row, column: "MAG_COURSE"),
        magneticCourseOppositeDeg: self.parseOptionalFloat(row, column: "OPP_MAG_COURSE"),
        trackAngleOutbound: nil,
        trackAngleInbound: nil,
        hasSignalCoverageGap: hasSignalCoverageGap,
        isUSAirspaceOnly: false,
        isAirwayGap: isAirwayGap,
        isDogleg: isDogleg,
        ARTCCID: ARTCCID?.isEmpty == true ? nil : ARTCCID
      )

      self.segments[segmentKey] = segment
    }
  }

  func finish(data: NASRData) async {
    // Assemble airways from collected data
    for (airwayKey, var airway) in airways {
      let airwaySegments = segments.filter { $0.key.airwayKey == airwayKey }
        .sorted { $0.key.sequenceNumber < $1.key.sequenceNumber }
        .map(\.value)

      airway.segments = airwaySegments
      airways[airwayKey] = airway
    }

    await data.finishParsing(airways: Array(airways.values))
  }

  // MARK: - Helper methods

  private func parseOptionalUInt(_ row: CSVRow, column: String) -> UInt? {
    guard let value = row[ifExists: column], !value.isEmpty else { return nil }
    return UInt(value)
  }

  private func parseOptionalFloat(_ row: CSVRow, column: String) -> Float? {
    guard let value = row[ifExists: column], !value.isEmpty else { return nil }
    return Float(value)
  }

  private func parseBoundDirection(_ row: CSVRow, column: String) throws -> BoundDirection? {
    guard let str = row[ifExists: column], !str.isEmpty else { return nil }
    // Handle the case where only "BND" appears without a direction prefix
    if str == "BND" { return nil }
    guard let direction = BoundDirection(rawValue: str) else {
      throw ParserError.invalidValue(str)
    }
    return direction
  }
}
