import Foundation

enum AirwayRecordIdentifier: String {
  case basicAndMEA = "AWY1"
  case pointDescription = "AWY2"
  case changeoverPoint = "AWY3"
  case pointRemarks = "AWY4"
  case changeoverException = "AWY5"
  case airwayRemark = "RMK "
}

struct AirwayKey: Hashable {
  let designation: String
  let type: Airway.AirwayType

  init(airway: Airway) {
    designation = airway.designation
    type = airway.type
  }

  init(designation: String, type: Airway.AirwayType) {
    self.designation = designation
    self.type = type
  }
}

struct SegmentKey: Hashable {
  let airwayKey: AirwayKey
  let sequenceNumber: UInt
}

actor FixedWidthAirwayParser: FixedWidthParser {
  typealias RecordIdentifier = AirwayRecordIdentifier

  static let type: RecordType = .airways
  static let layoutFormatOrder: [AirwayRecordIdentifier] = [
    .basicAndMEA, .pointDescription, .changeoverPoint, .pointRemarks, .changeoverException,
    .airwayRemark
  ]

  var recordTypeRange: Range<UInt> { 0..<4 }
  var formats = [NASRTable]()
  var airways = [AirwayKey: Airway]()
  var segments = [SegmentKey: Airway.Segment]()
  var points = [SegmentKey: Airway.Point]()
  var changeoverPoints = [SegmentKey: Airway.ChangeoverPoint]()

  // AWY1 - Basic and MEA data
  // Layout positions based on awy_rf.txt
  private let basicTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type (AWY1)
    .string(),  //  1 airway designation
    .generic({ try raw($0, toEnum: Airway.AirwayType.self) }, nullable: .blank),  //  2 airway type
    .unsignedInteger(),  //  3 point sequence number
    .null,  //  4 effective date
    .string(nullable: .blank),  //  5 track angle outbound (RNAV)
    .unsignedInteger(nullable: .blank),  //  6 distance to changeover point (RNAV)
    .string(nullable: .blank),  //  7 track angle inbound (RNAV)
    .float(nullable: .blank),  //  8 distance to next point
    .null,  //  9 bearing (reserved)
    .float(nullable: .blank),  // 10 segment magnetic course
    .float(nullable: .blank),  // 11 segment magnetic course opposite
    .float(nullable: .blank),  // 12 distance to next point in segment
    .unsignedInteger(nullable: .blank),  // 13 MEA
    .string(nullable: .blank),  // 14 MEA direction
    .unsignedInteger(nullable: .blank),  // 15 MEA opposite
    .string(nullable: .blank),  // 16 MEA opposite direction
    .unsignedInteger(nullable: .blank),  // 17 MAA
    .unsignedInteger(nullable: .blank),  // 18 MOCA
    .boolean(trueValue: "X", nullable: .blank),  // 19 airway gap flag
    .unsignedInteger(nullable: .blank),  // 20 distance to changeover point
    .unsignedInteger(nullable: .blank),  // 21 MCA
    .string(nullable: .blank),  // 22 MCA direction
    .unsignedInteger(nullable: .blank),  // 23 MCA opposite
    .string(nullable: .blank),  // 24 MCA opposite direction
    .boolean(nullable: .blank),  // 25 gap in signal coverage
    .boolean(nullable: .blank),  // 26 US airspace only
    .string(nullable: .blank),  // 27 navaid magnetic variation
    .string(nullable: .blank),  // 28 ARTCC ID
    .null,  // 29 reserved (to point part95)
    .null,  // 30 reserved (next MEA point part95)
    .unsignedInteger(nullable: .blank),  // 31 GNSS MEA
    .string(nullable: .blank),  // 32 GNSS MEA direction
    .unsignedInteger(nullable: .blank),  // 33 GNSS MEA opposite
    .string(nullable: .blank),  // 34 GNSS MEA opposite direction
    .null,  // 35 MCA point
    .unsignedInteger(nullable: .blank),  // 36 DME/DME/IRU MEA
    .string(nullable: .blank),  // 37 DME/DME/IRU MEA direction
    .unsignedInteger(nullable: .blank),  // 38 DME/DME/IRU MEA opposite
    .string(nullable: .blank),  // 39 DME/DME/IRU MEA opposite direction
    .boolean(nullable: .blank),  // 40 dogleg flag
    .float(nullable: .blank),  // 41 RNP
    .null  // 42 record sort sequence
  ])

  // AWY2 - Point description
  private let pointTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type (AWY2)
    .string(),  //  1 airway designation
    .generic({ try raw($0, toEnum: Airway.AirwayType.self) }, nullable: .blank),  //  2 airway type
    .unsignedInteger(),  //  3 point sequence number
    .string(nullable: .blank),  //  4 navaid/fix name
    .string(nullable: .blank),  //  5 navaid/fix type
    .string(nullable: .blank),  //  6 fix type publication category
    .string(nullable: .blank),  //  7 state PO code
    .string(nullable: .blank),  //  8 ICAO region code
    .DDMMSS(nullable: .blank),  //  9 latitude
    .DDMMSS(nullable: .blank),  // 10 longitude
    .unsignedInteger(nullable: .blank),  // 11 fix MRA
    .string(nullable: .blank),  // 12 navaid identifier
    .null,  // 13 reserved (from point part95)
    .null,  // 14 blanks
    .null  // 15 record sort sequence
  ])

  // AWY3 - Changeover point navaid
  private let changeoverTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type (AWY3)
    .string(),  //  1 airway designation
    .generic({ try raw($0, toEnum: Airway.AirwayType.self) }, nullable: .blank),  //  2 airway type
    .unsignedInteger(),  //  3 point sequence number
    .string(nullable: .blank),  //  4 navaid name
    .string(nullable: .blank),  //  5 navaid type
    .string(nullable: .blank),  //  6 state PO code
    .DDMMSS(nullable: .blank),  //  7 latitude
    .DDMMSS(nullable: .blank),  //  8 longitude
    .null,  //  9 blanks
    .null  // 10 record sort sequence
  ])

  // AWY4 - Point remarks
  private let pointRemarkTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type (AWY4)
    .string(),  //  1 airway designation
    .generic({ try raw($0, toEnum: Airway.AirwayType.self) }, nullable: .blank),  //  2 airway type
    .unsignedInteger(),  //  3 point sequence number
    .string(nullable: .blank),  //  4 remark text
    .null,  //  5 blanks
    .null  //  6 record sort sequence
  ])

  // AWY5 - Changeover exception
  private let changeoverExceptionTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type (AWY5)
    .string(),  //  1 airway designation
    .generic({ try raw($0, toEnum: Airway.AirwayType.self) }, nullable: .blank),  //  2 airway type
    .unsignedInteger(),  //  3 point sequence number
    .string(nullable: .blank),  //  4 exception text
    .null,  //  5 blanks
    .null  //  6 record sort sequence
  ])

  // RMK - Airway remark
  private let airwayRemarkTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type (RMK )
    .string(),  //  1 airway designation
    .generic({ try raw($0, toEnum: Airway.AirwayType.self) }, nullable: .blank),  //  2 airway type
    .null,  //  3 remark sequence number
    .string(nullable: .blank),  //  4 remark reference
    .string(nullable: .blank),  //  5 remark text
    .null,  //  6 blanks
    .null  //  7 record sort sequence
  ])

  func parseValues(_ values: [String], for identifier: AirwayRecordIdentifier) throws {
    switch identifier {
      case .basicAndMEA: try parseBasicRecord(values)
      case .pointDescription: try parsePointRecord(values)
      case .changeoverPoint: try parseChangeoverRecord(values)
      case .pointRemarks: try parsePointRemark(values)
      case .changeoverException: try parseChangeoverException(values)
      case .airwayRemark: try parseAirwayRemark(values)
    }
  }

  func finish(data: NASRData) async {
    // Assemble airways from collected data
    for (airwayKey, var airway) in airways {
      // Get all segments for this airway, sorted by sequence number
      let airwaySegments = segments.filter { $0.key.airwayKey == airwayKey }
        .sorted { $0.key.sequenceNumber < $1.key.sequenceNumber }
        .map(\.value)

      airway.segments = airwaySegments
      airways[airwayKey] = airway
    }

    await data.finishParsing(airways: Array(airways.values))
  }

  /// Creates a Location from optional lat/lon, throwing if only one is present.
  private func makeLocation(
    latitude: Float?,
    longitude: Float?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        return Location(latitudeArcsec: lat, longitudeArcsec: lon)
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

  private func parseBasicRecord(_ values: [String]) throws {
    let transformedValues = try basicTransformer.applyTo(values)

    let designation = transformedValues[1] as! String
    let type = transformedValues[2] as? Airway.AirwayType ?? .federal
    let sequenceNumber = transformedValues[3] as! UInt

    let airwayKey = AirwayKey(designation: designation, type: type)
    let segmentKey = SegmentKey(airwayKey: airwayKey, sequenceNumber: sequenceNumber)

    // Create or get the airway
    if airways[airwayKey] == nil {
      airways[airwayKey] = Airway(designation: designation, type: type)
    }

    // Create altitude info
    let altitudes = Airway.SegmentAltitudes(
      MEAFt: transformedValues[13] as? UInt,
      MEADirection: try parseBoundDirection(transformedValues[14] as? String),
      MEAOppositeFt: transformedValues[15] as? UInt,
      MEAOppositeDirection: try parseBoundDirection(transformedValues[16] as? String),
      MAAFt: transformedValues[17] as? UInt,
      MOCAFt: transformedValues[18] as? UInt,
      MCAFt: transformedValues[21] as? UInt,
      MCADirection: try parseBoundDirection(transformedValues[22] as? String),
      MCAOppositeFt: transformedValues[23] as? UInt,
      MCAOppositeDirection: try parseBoundDirection(transformedValues[24] as? String),
      GNSS_MEAFt: transformedValues[31] as? UInt,
      GNSS_MEADirection: try parseBoundDirection(transformedValues[32] as? String),
      GNSS_MEAOppositeFt: transformedValues[33] as? UInt,
      GNSS_MEAOppositeDirection: try parseBoundDirection(transformedValues[34] as? String),
      DME_MEAFt: transformedValues[36] as? UInt,
      DME_MEADirection: try parseBoundDirection(transformedValues[37] as? String),
      DME_MEAOppositeFt: transformedValues[38] as? UInt,
      DME_MEAOppositeDirection: try parseBoundDirection(transformedValues[39] as? String)
    )

    // Create placeholder point (will be populated by AWY2)
    let point =
      points[segmentKey]
      ?? Airway.Point(
        sequenceNumber: sequenceNumber,
        name: nil,  // placeholder, replaced by AWY2
        pointType: nil,  // placeholder, replaced by AWY2
        position: nil,
        stateCode: nil,
        ICAORegionCode: nil,
        navaidId: nil,
        minimumReceptionAltitudeFt: nil
      )

    // Create segment
    // Field 12 is "distance to next point in segment", field 8 is RNAV-specific
    let segment = Airway.Segment(
      sequenceNumber: sequenceNumber,
      point: point,
      changeoverPoint: changeoverPoints[segmentKey],
      altitudes: altitudes,
      distanceToNextNM: transformedValues[12] as? Float,
      magneticCourseDeg: transformedValues[10] as? Float,
      magneticCourseOppositeDeg: transformedValues[11] as? Float,
      trackAngleOutbound: try (transformedValues[5] as? String).map {
        try TrackAnglePair(parsing: $0)
      },
      trackAngleInbound: try (transformedValues[7] as? String).map {
        try TrackAnglePair(parsing: $0)
      },
      hasSignalCoverageGap: transformedValues[25] as? Bool,
      isUSAirspaceOnly: transformedValues[26] as? Bool,
      isAirwayGap: transformedValues[19] as? Bool,
      isDogleg: transformedValues[40] as? Bool,
      ARTCCID: transformedValues[28] as? String
    )

    segments[segmentKey] = segment
  }

  private func parsePointRecord(_ values: [String]) throws {
    let transformedValues = try pointTransformer.applyTo(values)

    let designation = transformedValues[1] as! String
    let type = transformedValues[2] as? Airway.AirwayType ?? .federal
    let sequenceNumber = transformedValues[3] as! UInt

    let airwayKey = AirwayKey(designation: designation, type: type)
    let segmentKey = SegmentKey(airwayKey: airwayKey, sequenceNumber: sequenceNumber)

    let ptPosition = try makeLocation(
      latitude: transformedValues[9] as? Float,
      longitude: transformedValues[10] as? Float,
      context: "airway \(designation) point \(sequenceNumber)"
    )

    let pointName = transformedValues[4] as? String
    let pointTypeStr = transformedValues[5] as? String
    let pointType = pointTypeStr.flatMap { Airway.PointType(rawValue: $0) }
    let point = Airway.Point(
      sequenceNumber: sequenceNumber,
      name: pointName,
      pointType: pointType,
      position: ptPosition,
      stateCode: transformedValues[7] as? String,
      ICAORegionCode: transformedValues[8] as? String,
      navaidId: transformedValues[12] as? String,
      minimumReceptionAltitudeFt: transformedValues[11] as? UInt
    )

    points[segmentKey] = point

    // Update segment if it exists
    if var segment = segments[segmentKey] {
      segment = Airway.Segment(
        sequenceNumber: segment.sequenceNumber,
        point: point,
        changeoverPoint: segment.changeoverPoint,
        altitudes: segment.altitudes,
        distanceToNextNM: segment.distanceToNextNM,
        magneticCourseDeg: segment.magneticCourseDeg,
        magneticCourseOppositeDeg: segment.magneticCourseOppositeDeg,
        trackAngleOutbound: segment.trackAngleOutbound,
        trackAngleInbound: segment.trackAngleInbound,
        hasSignalCoverageGap: segment.hasSignalCoverageGap,
        isUSAirspaceOnly: segment.isUSAirspaceOnly,
        isAirwayGap: segment.isAirwayGap,
        isDogleg: segment.isDogleg,
        ARTCCID: segment.ARTCCID,
        changeoverExceptions: segment.changeoverExceptions
      )
      segments[segmentKey] = segment
    }
  }

  private func parseChangeoverRecord(_ values: [String]) throws {
    let transformedValues = try changeoverTransformer.applyTo(values)

    let designation = transformedValues[1] as! String
    let type = transformedValues[2] as? Airway.AirwayType ?? .federal
    let sequenceNumber = transformedValues[3] as! UInt

    let airwayKey = AirwayKey(designation: designation, type: type)
    let segmentKey = SegmentKey(airwayKey: airwayKey, sequenceNumber: sequenceNumber)

    let copPosition = try makeLocation(
      latitude: transformedValues[7] as? Float,
      longitude: transformedValues[8] as? Float,
      context: "airway \(designation) changeover point \(sequenceNumber)"
    )

    let changeoverPoint = Airway.ChangeoverPoint(
      distanceNM: nil,  // Distance comes from AWY1 record
      navaidName: transformedValues[4] as? String,
      navaidType: transformedValues[5] as? String,
      position: copPosition,
      stateCode: transformedValues[6] as? String
    )

    changeoverPoints[segmentKey] = changeoverPoint

    // Update segment if it exists
    if var segment = segments[segmentKey] {
      segment = Airway.Segment(
        sequenceNumber: segment.sequenceNumber,
        point: segment.point,
        changeoverPoint: changeoverPoint,
        altitudes: segment.altitudes,
        distanceToNextNM: segment.distanceToNextNM,
        magneticCourseDeg: segment.magneticCourseDeg,
        magneticCourseOppositeDeg: segment.magneticCourseOppositeDeg,
        trackAngleOutbound: segment.trackAngleOutbound,
        trackAngleInbound: segment.trackAngleInbound,
        hasSignalCoverageGap: segment.hasSignalCoverageGap,
        isUSAirspaceOnly: segment.isUSAirspaceOnly,
        isAirwayGap: segment.isAirwayGap,
        isDogleg: segment.isDogleg,
        ARTCCID: segment.ARTCCID,
        changeoverExceptions: segment.changeoverExceptions
      )
      segments[segmentKey] = segment
    }
  }

  private func parsePointRemark(_ values: [String]) throws {
    let transformedValues = try pointRemarkTransformer.applyTo(values)

    let designation = transformedValues[1] as! String
    let type = transformedValues[2] as? Airway.AirwayType ?? .federal
    let sequenceNumber = transformedValues[3] as! UInt

    guard let remarkText = transformedValues[4] as? String, !remarkText.isEmpty else {
      return
    }

    let airwayKey = AirwayKey(designation: designation, type: type)
    let segmentKey = SegmentKey(airwayKey: airwayKey, sequenceNumber: sequenceNumber)

    // Update point remarks
    if var point = points[segmentKey] {
      point.remarks.append(remarkText)
      points[segmentKey] = point
    }
  }

  private func parseChangeoverException(_ values: [String]) throws {
    let transformedValues = try changeoverExceptionTransformer.applyTo(values)

    let designation = transformedValues[1] as! String
    let type = transformedValues[2] as? Airway.AirwayType ?? .federal
    let sequenceNumber = transformedValues[3] as! UInt

    guard let exceptionText = transformedValues[4] as? String, !exceptionText.isEmpty else {
      return
    }

    let airwayKey = AirwayKey(designation: designation, type: type)
    let segmentKey = SegmentKey(airwayKey: airwayKey, sequenceNumber: sequenceNumber)

    // Update segment changeover exceptions
    if var segment = segments[segmentKey] {
      segment.changeoverExceptions.append(exceptionText)
      segments[segmentKey] = segment
    }
  }

  private func parseAirwayRemark(_ values: [String]) throws {
    let transformedValues = try airwayRemarkTransformer.applyTo(values)

    let designation = transformedValues[1] as! String
    let type = transformedValues[2] as? Airway.AirwayType ?? .federal

    guard let remarkText = transformedValues[5] as? String, !remarkText.isEmpty else {
      return
    }

    let airwayKey = AirwayKey(designation: designation, type: type)

    // Create airway if it doesn't exist
    if airways[airwayKey] == nil {
      airways[airwayKey] = Airway(designation: designation, type: type)
    }

    airways[airwayKey]?.remarks.append(remarkText)
  }

  /// Parse a bound direction string (e.g., "E BND", "SE BND").
  private func parseBoundDirection(_ str: String?) throws -> BoundDirection? {
    guard let str, !str.isEmpty else { return nil }
    // Handle the case where only "BND" appears without a direction prefix
    if str == "BND" { return nil }
    guard let direction = BoundDirection(rawValue: str) else {
      throw ParserError.invalidValue(str)
    }
    return direction
  }
}
