import Foundation
import StreamingCSV

/// CSV Military Training Route Parser for parsing MTR_BASE.csv, MTR_AGY.csv,
/// MTR_PT.csv, MTR_SOP.csv, MTR_TERR.csv, and MTR_WDTH.csv
actor CSVMilitaryTrainingRouteParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = [
    "MTR_BASE.csv", "MTR_AGY.csv", "MTR_PT.csv",
    "MTR_SOP.csv", "MTR_TERR.csv", "MTR_WDTH.csv"
  ]

  var routes = [String: MilitaryTrainingRoute]()

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse MTR_BASE.csv
    try await parseCSVFile(
      filename: "MTR_BASE.csv",
      requiredColumns: ["ROUTE_TYPE_CODE", "ROUTE_ID"]
    ) { row in
      let routeTypeCode = try row["ROUTE_TYPE_CODE"]
      let routeId = try row["ROUTE_ID"]
      guard !routeTypeCode.isEmpty, !routeId.isEmpty else { return }

      guard let routeType = MilitaryTrainingRoute.RouteType(rawValue: routeTypeCode) else {
        throw ParserError.unknownRecordEnumValue(routeTypeCode)
      }

      let key = "\(routeTypeCode)\(routeId)"

      // Parse effective date (format: YYYY/MM/DD)
      let effectiveDate: DateComponents? = {
        guard let dateStr = row[ifExists: "EFF_DATE"] else { return nil }
        return DateFormat.yearMonthDaySlash.parse(dateStr)
      }()

      // Parse ARTCC identifiers - space-separated in CSV
      let ARTCCs: [String] = {
        guard let ARTCCStr = row[ifExists: "ARTCC"] else { return [] }
        return ARTCCStr.split(separator: " ").map { String($0) }
      }()

      // Parse FSS identifiers - space-separated in CSV
      let FSSes: [String] = {
        guard let FSSStr = row[ifExists: "FSS"] else { return [] }
        return FSSStr.split(separator: " ").map { String($0) }
      }()

      let timesOfUse = row[ifExists: "TIME_OF_USE"]

      let route = MilitaryTrainingRoute(
        routeType: routeType,
        routeIdentifier: routeId,
        effectiveDateComponents: effectiveDate,
        FAARegionCode: nil,  // Not in CSV format
        ARTCCIdentifiers: ARTCCs,
        FSSIdentifiers: FSSes,
        timesOfUse: timesOfUse,
        operatingProcedures: [],
        routeWidthDescriptions: [],
        terrainFollowingOperations: [],
        routePoints: [],
        agencies: []
      )

      self.routes[key] = route
    }

    // Parse MTR_AGY.csv for agencies
    try await parseCSVFile(
      filename: "MTR_AGY.csv",
      requiredColumns: ["ROUTE_TYPE_CODE", "ROUTE_ID"]
    ) { row in
      let routeTypeCode = try row["ROUTE_TYPE_CODE"]
      let routeId = try row["ROUTE_ID"]
      let key = "\(routeTypeCode)\(routeId)"

      guard !key.isEmpty, self.routes[key] != nil else { return }

      let agencyTypeStr = row[ifExists: "AGENCY_TYPE"] ?? ""
      let agencyType = MilitaryTrainingRoute.AgencyType(rawValue: agencyTypeStr)

      let agency = MilitaryTrainingRoute.Agency(
        agencyType: agencyType,
        organizationName: row[ifExists: "AGENCY_NAME"],
        station: row[ifExists: "STATION"],
        address: row[ifExists: "ADDRESS"],
        city: row[ifExists: "CITY"],
        stateCode: row[ifExists: "STATE_CODE"],
        zipCode: row[ifExists: "ZIP_CODE"],
        commercialPhone: row[ifExists: "COMMERCIAL_NO"],
        DSNPhone: row[ifExists: "DSN_NO"],
        hours: row[ifExists: "HOURS"]
      )

      self.routes[key]?.agencies.append(agency)
    }

    // Parse MTR_PT.csv for route points
    try await parseCSVFile(
      filename: "MTR_PT.csv",
      requiredColumns: ["ROUTE_TYPE_CODE", "ROUTE_ID", "LAT_DECIMAL", "LONG_DECIMAL"]
    ) { row in
      let routeTypeCode = try row["ROUTE_TYPE_CODE"]
      let routeId = try row["ROUTE_ID"]
      let key = "\(routeTypeCode)\(routeId)"

      guard !key.isEmpty, self.routes[key] != nil else { return }

      let seqStr = row[ifExists: "ROUTE_PT_SEQ"] ?? ""
      let pointId = row[ifExists: "ROUTE_PT_ID"] ?? ""
      let segmentText = row[ifExists: "SEGMENT_TEXT"]

      // Use LAT_DECIMAL and LONG_DECIMAL directly (already in decimal degrees)
      let latDecimalStr = try row["LAT_DECIMAL"]
      let lonDecimalStr = try row["LONG_DECIMAL"]

      let position: Location? = {
        guard let lat = Double(latDecimalStr),
          let lon = Double(lonDecimalStr)
        else { return nil }
        // Convert decimal degrees to arc-seconds (multiply by 3600)
        return Location(latitudeArcsec: Float(lat * 3600), longitudeArcsec: Float(lon * 3600))
      }()

      let bearingStr = row[ifExists: "NAVAID_BEARING"] ?? ""
      let distStr = row[ifExists: "NAVAID_DIST"] ?? ""

      let point = MilitaryTrainingRoute.RoutePoint(
        pointId: pointId,
        segmentDescriptionLeading: segmentText,
        segmentDescriptionLeaving: nil,  // CSV format combines into single field
        navaidIdentifier: row[ifExists: "NAV_ID"],
        navaidBearingDeg: UInt(bearingStr),
        navaidDistanceNM: UInt(distStr),
        position: position,
        sequenceNumber: UInt(seqStr)
      )

      self.routes[key]?.routePoints.append(point)
    }

    // Parse MTR_SOP.csv for standard operating procedures
    try await parseCSVFile(
      filename: "MTR_SOP.csv",
      requiredColumns: ["ROUTE_TYPE_CODE", "ROUTE_ID", "SOP_TEXT"]
    ) { row in
      let routeTypeCode = try row["ROUTE_TYPE_CODE"]
      let routeId = try row["ROUTE_ID"]
      let key = "\(routeTypeCode)\(routeId)"

      guard !key.isEmpty, self.routes[key] != nil else { return }

      let text = try row["SOP_TEXT"]
      if !text.isEmpty {
        self.routes[key]?.operatingProcedures.append(text)
      }
    }

    // Parse MTR_TERR.csv for terrain following operations
    try await parseCSVFile(
      filename: "MTR_TERR.csv",
      requiredColumns: ["ROUTE_TYPE_CODE", "ROUTE_ID", "TERRAIN_TEXT"]
    ) { row in
      let routeTypeCode = try row["ROUTE_TYPE_CODE"]
      let routeId = try row["ROUTE_ID"]
      let key = "\(routeTypeCode)\(routeId)"

      guard !key.isEmpty, self.routes[key] != nil else { return }

      let text = try row["TERRAIN_TEXT"]
      if !text.isEmpty {
        self.routes[key]?.terrainFollowingOperations.append(text)
      }
    }

    // Parse MTR_WDTH.csv for route width descriptions
    try await parseCSVFile(
      filename: "MTR_WDTH.csv",
      requiredColumns: ["ROUTE_TYPE_CODE", "ROUTE_ID", "WIDTH_TEXT"]
    ) { row in
      let routeTypeCode = try row["ROUTE_TYPE_CODE"]
      let routeId = try row["ROUTE_ID"]
      let key = "\(routeTypeCode)\(routeId)"

      guard !key.isEmpty, self.routes[key] != nil else { return }

      let text = try row["WIDTH_TEXT"]
      if !text.isEmpty {
        self.routes[key]?.routeWidthDescriptions.append(text)
      }
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(militaryTrainingRoutes: Array(routes.values))
  }
}
