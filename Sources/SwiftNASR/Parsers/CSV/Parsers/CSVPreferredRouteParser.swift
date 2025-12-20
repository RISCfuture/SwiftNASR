import Foundation
import StreamingCSV

/// CSV Preferred Route Parser for parsing PFR_BASE.csv and PFR_SEG.csv
actor CSVPreferredRouteParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["PFR_BASE.csv", "PFR_SEG.csv"]

  var routes = [String: PreferredRoute]()

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse PFR_BASE.csv
    // Columns: EFF_DATE(0), ORIGIN_ID(1), ORIGIN_CITY(2), ORIGIN_STATE_CODE(3),
    // ORIGIN_COUNTRY_CODE(4), DSTN_ID(5), DSTN_CITY(6), DSTN_STATE_CODE(7),
    // DSTN_COUNTRY_CODE(8), PFR_TYPE_CODE(9), ROUTE_NO(10), SPECIAL_AREA_DESCRIP(11),
    // ALT_DESCRIP(12), AIRCRAFT(13), HOURS(14), ROUTE_DIR_DESCRIP(15),
    // DESIGNATOR(16), NAR_TYPE(17), INLAND_FAC_FIX(18), COASTAL_FIX(19),
    // DESTINATION(20), ROUTE_STRING(21)
    try await parseCSVFile(filename: "PFR_BASE.csv", expectedFieldCount: 22) { fields in
      guard fields.count >= 11 else { return }

      let originID = fields[1].trimmingCharacters(in: .whitespaces)
      let destID = fields[5].trimmingCharacters(in: .whitespaces)
      let routeTypeCode = fields[9].trimmingCharacters(in: .whitespaces)
      let routeNoStr = fields[10].trimmingCharacters(in: .whitespaces)

      guard !originID.isEmpty, !destID.isEmpty, !routeTypeCode.isEmpty else { return }
      guard let routeNo = UInt(routeNoStr) else { return }

      let key = "\(originID)-\(destID)-\(routeTypeCode)-\(routeNo)"

      // Parse effective hours
      var effectiveHoursArray = [String]()
      if fields.count > 14 {
        let hours = fields[14].trimmingCharacters(in: .whitespaces)
        if !hours.isEmpty {
          effectiveHoursArray.append(hours)
        }
      }

      let route = PreferredRoute(
        originIdentifier: originID,
        destinationIdentifier: destID,
        routeType: PreferredRoute.RouteType.for(routeTypeCode),
        sequenceNumber: routeNo,
        routeTypeDescription: nil,  // Not in CSV
        areaDescription: fields.count > 11
          ? emptyToNil(fields[11].trimmingCharacters(in: .whitespaces)) : nil,
        altitudeDescription: fields.count > 12
          ? emptyToNil(fields[12].trimmingCharacters(in: .whitespaces)) : nil,
        aircraftDescription: fields.count > 13
          ? emptyToNil(fields[13].trimmingCharacters(in: .whitespaces)) : nil,
        effectiveHours: effectiveHoursArray,
        directionLimitations: fields.count > 15
          ? emptyToNil(fields[15].trimmingCharacters(in: .whitespaces)) : nil,
        NARType: fields.count > 17
          ? emptyToNil(fields[17].trimmingCharacters(in: .whitespaces))
          : nil,
        designator: fields.count > 16
          ? emptyToNil(fields[16].trimmingCharacters(in: .whitespaces)) : nil,
        destinationCity: fields.count > 20
          ? emptyToNil(fields[20].trimmingCharacters(in: .whitespaces)) : nil
      )

      self.routes[key] = route
    }

    // Parse PFR_SEG.csv for segments
    // Columns: EFF_DATE(0), ORIGIN_ID(1), DSTN_ID(2), PFR_TYPE_CODE(3), ROUTE_NO(4),
    // SEGMENT_SEQ(5), SEG_VALUE(6), SEG_TYPE(7), STATE_CODE(8), COUNTRY_CODE(9),
    // ICAO_REGION_CODE(10), NAV_TYPE(11), NEXT_SEG(12)
    try await parseCSVFile(filename: "PFR_SEG.csv", expectedFieldCount: 13) { fields in
      guard fields.count >= 8 else { return }

      let originID = fields[1].trimmingCharacters(in: .whitespaces)
      let destID = fields[2].trimmingCharacters(in: .whitespaces)
      let routeTypeCode = fields[3].trimmingCharacters(in: .whitespaces)
      let routeNoStr = fields[4].trimmingCharacters(in: .whitespaces)

      guard let routeNo = UInt(routeNoStr) else { return }
      let key = "\(originID)-\(destID)-\(routeTypeCode)-\(routeNo)"

      guard self.routes[key] != nil else { return }

      let segSeqStr = fields[5].trimmingCharacters(in: .whitespaces)
      guard let segSeq = UInt(segSeqStr) else { return }

      let segValue = fields[6].trimmingCharacters(in: .whitespaces)
      let segTypeStr = fields[7].trimmingCharacters(in: .whitespaces)
      let segmentType = PreferredRoute.SegmentType.for(segTypeStr)

      let stateCode =
        fields.count > 8
        ? emptyToNil(fields[8].trimmingCharacters(in: .whitespaces)) : nil
      let ICAORegionCode =
        fields.count > 10
        ? emptyToNil(fields[10].trimmingCharacters(in: .whitespaces)) : nil

      // Parse navaid type from NAV_TYPE column
      let navTypeStr = fields.count > 11 ? fields[11].trimmingCharacters(in: .whitespaces) : ""
      let navaidType = navTypeStr.isEmpty ? nil : Navaid.FacilityType.for(navTypeStr)

      // Parse radial/distance from segment value for FRD and RADIAL types
      let radialDistance = parseRadialDistance(segValue, segmentType: segmentType)

      let segment = PreferredRoute.Segment(
        sequenceNumber: segSeq,
        identifier: segValue.isEmpty ? nil : segValue,
        segmentType: segmentType,
        fixStateCode: stateCode,
        ICAORegionCode: ICAORegionCode,
        navaidType: navaidType,
        navaidTypeDescription: navTypeStr.isEmpty ? nil : navTypeStr,
        radialDistance: radialDistance
      )

      self.routes[key]?.segments.append(segment)
    }
  }

  /// Parses radial/distance from segment values like "PDZ270013" (FRD) or "PVD167" (RADIAL)
  private func parseRadialDistance(
    _ value: String,
    segmentType: PreferredRoute.SegmentType?
  ) -> PreferredRoute.RadialDistance? {
    guard let segmentType, !value.isEmpty else { return nil }

    switch segmentType {
      case .fixRadialDistance:
        // Format: NAVAID + 3-digit radial + 3-digit distance (e.g., "PDZ270013")
        // The navaid is typically 3 chars, but could vary
        // Look for 6 trailing digits: 3 for radial, 3 for distance
        guard value.count >= 6 else { return nil }
        let suffix = String(value.suffix(6))
        guard let radialDeg = UInt16(String(suffix.prefix(3))),
          let distanceNM = UInt16(String(suffix.suffix(3)))
        else { return nil }
        return .radialDistanceDegNM(radialDeg: radialDeg, distanceNM: distanceNM)

      case .radial:
        // Format: NAVAID + 3-digit radial (e.g., "PVD167")
        guard value.count >= 3 else { return nil }
        let suffix = String(value.suffix(3))
        guard let radialDeg = UInt16(suffix) else { return nil }
        return .radialDeg(radialDeg)

      default:
        return nil
    }
  }

  private func emptyToNil(_ string: String) -> String? {
    string.isEmpty ? nil : string
  }

  func finish(data: NASRData) async {
    // Sort segments by sequence number for each route
    for key in routes.keys {
      routes[key]?.segments.sort { $0.sequenceNumber < $1.sequenceNumber }
    }
    await data.finishParsing(preferredRoutes: Array(routes.values))
  }
}
