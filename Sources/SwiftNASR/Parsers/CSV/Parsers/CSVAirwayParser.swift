import Foundation
import StreamingCSV
import ZIPFoundation

/// CSV Airway Parser for parsing AWY_BASE.csv and AWY_SEG_ALT.csv
class CSVAirwayParser: CSVParser {
  var CSVDirectory = URL(fileURLWithPath: "/")
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["AWY_BASE.csv", "AWY_SEG_ALT.csv"]

  var airways = [AirwayKey: Airway]()
  var segments = [SegmentKey: Airway.Segment]()

  func prepare(distribution: Distribution) throws {
    if let dirDist = distribution as? DirectoryDistribution {
      CSVDirectory = dirDist.location
    } else if let archiveDist = distribution as? ArchiveFileDistribution {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        "SwiftNASR_CSV_\(UUID().uuidString)"
      )
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      try FileManager.default.unzipItem(at: archiveDist.location, to: tempDir)
      CSVDirectory = tempDir
    }
  }

  func parse(data _: Data) async throws {
    // First parse AWY_BASE.csv for airway definitions and remarks
    // Headers: EFF_DATE(0), REGULATORY(1), AWY_LOCATION(2), AWY_ID(3), SEQ_NO(4), RMK_CODE(5), REMARK(6), OBSOLETE(7)
    try await parseCSVFile(filename: "AWY_BASE.csv", expectedFieldCount: 8) { fields in
      guard fields.count >= 4 else {
        throw ParserError.truncatedRecord(
          recordType: "AWY_BASE",
          expectedMinLength: 4,
          actualLength: fields.count
        )
      }

      let location = fields[2].trimmingCharacters(in: .whitespaces)  // AWY_LOCATION
      let designation = fields[3].trimmingCharacters(in: .whitespaces)  // AWY_ID
      let remark = fields.count > 6 ? fields[6].trimmingCharacters(in: .whitespaces) : ""

      // Determine type from location code
      let type: Airway.AirwayType
      switch location {
        case "A": type = .alaska
        case "H": type = .hawaii
        default: type = .federal
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
    // Headers: EFF_DATE,REGULATORY,AWY_LOCATION,AWY_ID,POINT_SEQ,FROM_POINT,FROM_PT_TYPE,
    //          NAV_NAME,NAV_CITY,ARTCC,ICAO_REGION_CODE,STATE_CODE,COUNTRY_CODE,TO_POINT,
    //          MAG_COURSE,OPP_MAG_COURSE,MAG_COURSE_DIST,CHGOVR_PT,CHGOVR_PT_NAME,CHGOVR_PT_DIST,
    //          AWY_SEG_GAP_FLAG,SIGNAL_GAP_FLAG,DOGLEG,NEXT_MEA_PT,MIN_ENROUTE_ALT,MIN_ENROUTE_ALT_DIR,
    //          MIN_ENROUTE_ALT_OPPOSITE,MIN_ENROUTE_ALT_OPPOSITE_DIR,GPS_MIN_ENROUTE_ALT,GPS_MIN_ENROUTE_ALT_DIR,
    //          GPS_MIN_ENROUTE_ALT_OPPOSITE,GPS_MEA_OPPOSITE_DIR,DD_IRU_MEA,DD_IRU_MEA_DIR,
    //          DD_I_MEA_OPPOSITE,DD_I_MEA_OPPOSITE_DIR,MIN_OBSTN_CLNC_ALT,MIN_CROSS_ALT,
    //          MIN_CROSS_ALT_DIR,MIN_CROSS_ALT_NAV_PT,MIN_CROSS_ALT_OPPOSITE,MIN_CROSS_ALT_OPPOSITE_DIR,
    //          MIN_RECEP_ALT,MAX_AUTH_ALT,MEA_GAP,REQD_NAV_PERFORMANCE,REMARK
    try await parseCSVFile(filename: "AWY_SEG_ALT.csv", expectedFieldCount: 47) { fields in
      guard fields.count >= 25 else {
        throw ParserError.truncatedRecord(
          recordType: "AWY_SEG_ALT",
          expectedMinLength: 25,
          actualLength: fields.count
        )
      }

      let location = fields[2].trimmingCharacters(in: .whitespaces)  // AWY_LOCATION
      let designation = fields[3].trimmingCharacters(in: .whitespaces)  // AWY_ID
      let seqStr = fields[4].trimmingCharacters(in: .whitespaces)
      guard let sequenceNumber = UInt(seqStr) else {
        throw ParserError.missingRequiredField(field: "sequenceNumber", recordType: "AWY_SEG_ALT")
      }

      let type: Airway.AirwayType
      switch location {
        case "A": type = .alaska
        case "H": type = .hawaii
        default: type = .federal
      }

      let airwayKey = AirwayKey(designation: designation, type: type)
      let segmentKey = SegmentKey(airwayKey: airwayKey, sequenceNumber: sequenceNumber)

      // Create airway if it doesn't exist
      if self.airways[airwayKey] == nil {
        self.airways[airwayKey] = Airway(designation: designation, type: type)
      }

      // Parse point data
      let fromPoint = fields[5].trimmingCharacters(in: .whitespaces)
      let pointTypeStr = fields[6].trimmingCharacters(in: .whitespaces)
      let pointType = Airway.PointType(rawValue: pointTypeStr)
      let stateCode = fields.count > 11 ? fields[11].trimmingCharacters(in: .whitespaces) : nil
      let ICAORegion = fields.count > 10 ? fields[10].trimmingCharacters(in: .whitespaces) : nil
      let ARTCCID = fields.count > 9 ? fields[9].trimmingCharacters(in: .whitespaces) : nil

      let point = Airway.Point(
        sequenceNumber: sequenceNumber,
        name: fromPoint.isEmpty ? nil : fromPoint,
        pointType: pointType,
        position: nil,  // Not in CSV
        stateCode: stateCode?.isEmpty == true ? nil : stateCode,
        ICAORegionCode: ICAORegion?.isEmpty == true ? nil : ICAORegion,
        navaidId: nil,
        minimumReceptionAltitudeFt: self.parseOptionalUInt(fields, index: 42)  // MIN_RECEP_ALT
      )

      // Parse changeover point if present
      var changeoverPoint: Airway.ChangeoverPoint?
      let chgovrPtName = fields.count > 18 ? fields[18].trimmingCharacters(in: .whitespaces) : ""
      if !chgovrPtName.isEmpty {
        changeoverPoint = Airway.ChangeoverPoint(
          distanceNM: self.parseOptionalUInt(fields, index: 19),  // CHGOVR_PT_DIST
          navaidName: chgovrPtName,
          navaidType: nil,
          position: nil,
          stateCode: nil
        )
      }

      // Parse altitudes
      let altitudes = try Airway.SegmentAltitudes(
        MEAFt: self.parseOptionalUInt(fields, index: 24),  // MIN_ENROUTE_ALT
        MEADirection: self.parseBoundDirection(fields, index: 25),  // MIN_ENROUTE_ALT_DIR
        MEAOppositeFt: self.parseOptionalUInt(fields, index: 26),  // MIN_ENROUTE_ALT_OPPOSITE
        MEAOppositeDirection: self.parseBoundDirection(fields, index: 27),
        // MIN_ENROUTE_ALT_OPPOSITE_DIR
        MAAFt: self.parseOptionalUInt(fields, index: 43),  // MAX_AUTH_ALT
        MOCAFt: self.parseOptionalUInt(fields, index: 36),  // MIN_OBSTN_CLNC_ALT
        MCAFt: self.parseOptionalUInt(fields, index: 37),  // MIN_CROSS_ALT
        MCADirection: self.parseBoundDirection(fields, index: 38),  // MIN_CROSS_ALT_DIR
        MCAOppositeFt: self.parseOptionalUInt(fields, index: 40),  // MIN_CROSS_ALT_OPPOSITE
        MCAOppositeDirection: self.parseBoundDirection(fields, index: 41),
        // MIN_CROSS_ALT_OPPOSITE_DIR
        GNSS_MEAFt: self.parseOptionalUInt(fields, index: 28),  // GPS_MIN_ENROUTE_ALT
        GNSS_MEADirection: self.parseBoundDirection(fields, index: 29),  // GPS_MIN_ENROUTE_ALT_DIR
        GNSS_MEAOppositeFt: self.parseOptionalUInt(fields, index: 30),  // GPS_MIN_ENROUTE_ALT_OPPOSITE
        GNSS_MEAOppositeDirection: self.parseBoundDirection(fields, index: 31),  // GPS_MEA_OPPOSITE_DIR
        DME_MEAFt: self.parseOptionalUInt(fields, index: 32),  // DD_IRU_MEA
        DME_MEADirection: self.parseBoundDirection(fields, index: 33),  // DD_IRU_MEA_DIR
        DME_MEAOppositeFt: self.parseOptionalUInt(fields, index: 34),  // DD_I_MEA_OPPOSITE
        DME_MEAOppositeDirection: self.parseBoundDirection(fields, index: 35)  // DD_I_MEA_OPPOSITE_DIR
      )

      // Parse segment flags
      let isAirwayGap =
        fields.count > 20 && fields[20].trimmingCharacters(in: .whitespaces).uppercased() == "Y"
      let hasSignalCoverageGap =
        fields.count > 21 && fields[21].trimmingCharacters(in: .whitespaces).uppercased() == "Y"
      let isDogleg =
        fields.count > 22 && fields[22].trimmingCharacters(in: .whitespaces).uppercased() == "Y"

      let segment = Airway.Segment(
        sequenceNumber: sequenceNumber,
        point: point,
        changeoverPoint: changeoverPoint,
        altitudes: altitudes,
        distanceToNextNM: self.parseOptionalFloat(fields, index: 16),  // MAG_COURSE_DIST
        magneticCourseDeg: self.parseOptionalFloat(fields, index: 14),  // MAG_COURSE
        magneticCourseOppositeDeg: self.parseOptionalFloat(fields, index: 15),  // OPP_MAG_COURSE
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

  private func parseOptionalString(_ fields: [String], index: Int) -> String? {
    guard index < fields.count else { return nil }
    let value = fields[index].trimmingCharacters(in: .whitespaces)
    return value.isEmpty ? nil : value
  }

  private func parseBoundDirection(_ fields: [String], index: Int) throws -> BoundDirection? {
    guard let str = parseOptionalString(fields, index: index) else { return nil }
    // Handle the case where only "BND" appears without a direction prefix
    if str == "BND" { return nil }
    guard let direction = BoundDirection(rawValue: str) else {
      throw ParserError.invalidValue(str)
    }
    return direction
  }
}
