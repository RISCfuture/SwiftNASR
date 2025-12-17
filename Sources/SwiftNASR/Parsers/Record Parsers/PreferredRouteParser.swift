import Foundation

enum PFRRecordIdentifier: String {
  case base = "PFR1"
  case segment = "PFR2"
}

/// Parser for PFR (Preferred Routes) files.
///
/// These files contain preferred IFR routes between airports.
/// Records are 344 characters fixed-width with PFR1 (base) and PFR2 (segment) record types.
class FixedWidthPreferredRouteParser: FixedWidthParser {
  typealias RecordIdentifier = PFRRecordIdentifier

  static let type = RecordType.preferredRoutes
  static let layoutFormatOrder: [PFRRecordIdentifier] = [.base, .segment]

  var recordTypeRange: Range<UInt> { 0..<4 }
  var formats = [NASRTable]()
  var routes = [String: PreferredRoute]()

  private let baseTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type indicator (4)
    .string(),  // 1 origin identifier (5)
    .string(),  // 2 destination identifier (5)
    .string(),  // 3 route type code (3)
    .unsignedInteger(nullable: .blank),  // 4 sequence number (2)
    .string(nullable: .blank),  // 5 route type description (30)
    .string(nullable: .blank),  // 6 area description (75)
    .string(nullable: .blank),  // 7 altitude description (40)
    .string(nullable: .blank),  // 8 aircraft description (50)
    .string(nullable: .blank),  // 9 effective hours 1 (15)
    .string(nullable: .blank),  // 10 effective hours 2 (15)
    .string(nullable: .blank),  // 11 effective hours 3 (15)
    .string(nullable: .blank),  // 12 direction limitations (20)
    .string(nullable: .blank),  // 13 NAR type (20)
    .string(nullable: .blank),  // 14 designator (5)
    .string(nullable: .blank)  // 15 destination city (40)
  ])

  private let segmentTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type indicator (4)
    .string(),  // 1 origin identifier (5)
    .string(),  // 2 destination identifier (5)
    .string(),  // 3 route type code (3)
    .unsignedInteger(nullable: .blank),  // 4 route sequence number (2)
    .unsignedInteger(nullable: .blank),  // 5 segment sequence number (3)
    .string(nullable: .blank),  // 6 segment identifier (48)
    .string(nullable: .blank),  // 7 segment type (7)
    .string(nullable: .blank),  // 8 fix state code (2)
    .string(nullable: .blank),  // 9 ICAO region code (2)
    .string(nullable: .blank),  // 10 navaid type code (2)
    .string(nullable: .blank),  // 11 navaid type description (20)
    .string(nullable: .blank),  // 12 radial/distance (7)
    .null  // 13 blanks (234)
  ])

  func parseValues(_ values: [String], for identifier: PFRRecordIdentifier) throws {
    switch identifier {
      case .base:
        try parseBaseRecord(values)
      case .segment:
        try parseSegmentRecord(values)
    }
  }

  private func parseBaseRecord(_ values: [String]) throws {
    let transformedValues = try baseTransformer.applyTo(values)

    let originID = transformedValues[1] as! String
    let destID = transformedValues[2] as! String
    let routeTypeCode = transformedValues[3] as! String
    guard let seqNum = transformedValues[4] as? UInt else {
      throw ParserError.missingRequiredField(field: "sequenceNumber", recordType: "PFR1")
    }

    let routeKey = "\(originID)-\(destID)-\(routeTypeCode)-\(seqNum)"

    var effectiveHoursArray = [String]()
    if let h1 = transformedValues[9] as? String, !h1.isEmpty { effectiveHoursArray.append(h1) }
    if let h2 = transformedValues[10] as? String, !h2.isEmpty { effectiveHoursArray.append(h2) }
    if let h3 = transformedValues[11] as? String, !h3.isEmpty { effectiveHoursArray.append(h3) }

    let route = PreferredRoute(
      originIdentifier: originID,
      destinationIdentifier: destID,
      routeType: PreferredRoute.RouteType.for(routeTypeCode),
      sequenceNumber: seqNum,
      routeTypeDescription: transformedValues[5] as? String,
      areaDescription: transformedValues[6] as? String,
      altitudeDescription: transformedValues[7] as? String,
      aircraftDescription: transformedValues[8] as? String,
      effectiveHours: effectiveHoursArray,
      directionLimitations: transformedValues[12] as? String,
      NARType: transformedValues[13] as? String,
      designator: transformedValues[14] as? String,
      destinationCity: transformedValues[15] as? String
    )

    routes[routeKey] = route
  }

  private func parseSegmentRecord(_ values: [String]) throws {
    let transformedValues = try segmentTransformer.applyTo(values)

    let originID = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    let destID = (transformedValues[2] as! String).trimmingCharacters(in: .whitespaces)
    let routeTypeCode = (transformedValues[3] as! String).trimmingCharacters(in: .whitespaces)
    guard let routeSeqNum = transformedValues[4] as? UInt else {
      throw ParserError.missingRequiredField(field: "routeSequenceNumber", recordType: "PFR2")
    }

    let routeKey = "\(originID)-\(destID)-\(routeTypeCode)-\(routeSeqNum)"

    guard let segSeq = transformedValues[5] as? UInt else {
      throw ParserError.missingRequiredField(field: "segmentSequenceNumber", recordType: "PFR2")
    }

    let segment = PreferredRoute.Segment(
      sequenceNumber: segSeq,
      identifier: transformedValues[6] as? String,
      segmentType: (transformedValues[7] as? String).flatMap { PreferredRoute.SegmentType.for($0) },
      fixStateCode: transformedValues[8] as? String,
      ICAORegionCode: transformedValues[9] as? String,
      navaidType: (transformedValues[10] as? String).flatMap { Navaid.FacilityType.for($0) },
      navaidTypeDescription: transformedValues[11] as? String,
      radialDistance: parseRadialDistance(transformedValues[12] as? String)
    )

    guard routes[routeKey] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "PreferredRoute",
        parentID: routeKey,
        childType: "segment"
      )
    }
    routes[routeKey]?.segments.append(segment)
  }

  private func parseRadialDistance(_ value: String?) -> PreferredRoute.RadialDistance? {
    guard let value, !value.isEmpty else { return nil }

    if let slashIndex = value.firstIndex(of: "/") {
      let radialStr = String(value[..<slashIndex])
      let distanceStr = String(value[value.index(after: slashIndex)...])
      guard let radial = UInt16(radialStr), let distance = UInt16(distanceStr) else { return nil }
      return .radialDistance(radial: radial, distance: distance)
    }
    guard let radial = UInt16(value) else { return nil }
    return .radial(radial)
  }

  func finish(data: NASRData) async {
    await data.finishParsing(preferredRoutes: Array(routes.values))
  }
}
