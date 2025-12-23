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
    try await parseCSVFile(
      filename: "PFR_BASE.csv",
      requiredColumns: ["ORIGIN_ID", "DSTN_ID", "PFR_TYPE_CODE", "ROUTE_NO"]
    ) { row in
      let originID = try row["ORIGIN_ID"]
      let destID = try row["DSTN_ID"]
      let routeTypeCode = try row["PFR_TYPE_CODE"]
      let routeNoStr = try row["ROUTE_NO"]

      guard !originID.isEmpty, !destID.isEmpty, !routeTypeCode.isEmpty else { return }
      guard let routeNo = UInt(routeNoStr) else { return }

      let key = "\(originID)-\(destID)-\(routeTypeCode)-\(routeNo)"

      // Parse effective hours
      var effectiveHoursArray = [String]()
      if let hours = try row.optional("HOURS") {
        effectiveHoursArray.append(hours)
      }

      let route = PreferredRoute(
        originIdentifier: originID,
        destinationIdentifier: destID,
        routeType: PreferredRoute.RouteType.for(routeTypeCode),
        sequenceNumber: routeNo,
        routeTypeDescription: nil,  // Not in CSV
        areaDescription: try row.optional("SPECIAL_AREA_DESCRIP"),
        altitudeDescription: try row.optional("ALT_DESCRIP"),
        aircraftDescription: try row.optional("AIRCRAFT"),
        effectiveHours: effectiveHoursArray,
        directionLimitations: try row.optional("ROUTE_DIR_DESCRIP"),
        NARType: try row.optional("NAR_TYPE"),
        designator: try row.optional("DESIGNATOR"),
        destinationCity: try row.optional("DESTINATION")
      )

      self.routes[key] = route
    }

    // Parse PFR_SEG.csv for segments
    try await parseCSVFile(
      filename: "PFR_SEG.csv",
      requiredColumns: ["ORIGIN_ID", "DSTN_ID", "PFR_TYPE_CODE", "ROUTE_NO", "SEGMENT_SEQ"]
    ) { row in
      let originID = try row["ORIGIN_ID"]
      let destID = try row["DSTN_ID"]
      let routeTypeCode = try row["PFR_TYPE_CODE"]
      let routeNoStr = try row["ROUTE_NO"]

      guard let routeNo = UInt(routeNoStr) else { return }
      let key = "\(originID)-\(destID)-\(routeTypeCode)-\(routeNo)"

      guard self.routes[key] != nil else { return }

      let segSeqStr = try row["SEGMENT_SEQ"]
      guard let segSeq = UInt(segSeqStr) else { return }

      let segValue = try row.optional("SEG_VALUE") ?? ""
      let segTypeStr = try row.optional("SEG_TYPE") ?? ""
      let segmentType = PreferredRoute.SegmentType.for(segTypeStr)

      let stateCode = try row.optional("STATE_CODE")
      let ICAORegionCode = try row.optional("ICAO_REGION_CODE")

      // Parse navaid type from NAV_TYPE column
      let navTypeStr = try row.optional("NAV_TYPE") ?? ""
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

  func finish(data: NASRData) async {
    // Sort segments by sequence number for each route
    for key in routes.keys {
      routes[key]?.segments.sort { $0.sequenceNumber < $1.sequenceNumber }
    }
    await data.finishParsing(preferredRoutes: Array(routes.values))
  }
}
