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
    // Columns: EFF_DATE(0), ROUTE_TYPE_CODE(1), ROUTE_ID(2), ARTCC(3), FSS(4), TIME_OF_USE(5)
    try await parseCSVFile(filename: "MTR_BASE.csv", expectedFieldCount: 6) { fields in
      guard fields.count >= 3 else { return }

      let routeTypeCode = fields[1].trimmingCharacters(in: .whitespaces)
      let routeId = fields[2].trimmingCharacters(in: .whitespaces)
      guard !routeTypeCode.isEmpty, !routeId.isEmpty else { return }

      guard let routeType = MilitaryTrainingRoute.RouteType(rawValue: routeTypeCode) else {
        throw ParserError.unknownRecordEnumValue(routeTypeCode)
      }

      let key = "\(routeTypeCode)\(routeId)"

      // Parse effective date (format: YYYY/MM/DD)
      let effectiveDate: DateComponents? = {
        let dateStr = fields[0].trimmingCharacters(in: .whitespaces)
        guard !dateStr.isEmpty else { return nil }
        return DateFormat.yearMonthDaySlash.parse(dateStr)
      }()

      // Parse ARTCC identifiers - space-separated in CSV
      let ARTCCs: [String] = {
        guard fields.count > 3 else { return [] }
        let ARTCCStr = fields[3].trimmingCharacters(in: .whitespaces)
        guard !ARTCCStr.isEmpty else { return [] }
        return ARTCCStr.split(separator: " ").map { String($0) }
      }()

      // Parse FSS identifiers - space-separated in CSV
      let FSSes: [String] = {
        guard fields.count > 4 else { return [] }
        let FSSStr = fields[4].trimmingCharacters(in: .whitespaces)
        guard !FSSStr.isEmpty else { return [] }
        return FSSStr.split(separator: " ").map { String($0) }
      }()

      let timesOfUse: String? = {
        guard fields.count > 5 else { return nil }
        let str = fields[5].trimmingCharacters(in: .whitespaces)
        return str.isEmpty ? nil : str
      }()

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
    // Columns: EFF_DATE(0), ROUTE_TYPE_CODE(1), ROUTE_ID(2), ARTCC(3), AGENCY_TYPE(4),
    // AGENCY_NAME(5), STATION(6), ADDRESS(7), CITY(8), STATE_CODE(9), ZIP_CODE(10),
    // COMMERCIAL_NO(11), DSN_NO(12), HOURS(13)
    try await parseCSVFile(filename: "MTR_AGY.csv", expectedFieldCount: 14) { fields in
      guard fields.count >= 6 else { return }

      let routeTypeCode = fields[1].trimmingCharacters(in: .whitespaces)
      let routeId = fields[2].trimmingCharacters(in: .whitespaces)
      let key = "\(routeTypeCode)\(routeId)"

      guard !key.isEmpty, self.routes[key] != nil else { return }

      let agencyTypeStr = fields[4].trimmingCharacters(in: .whitespaces)
      let agencyType = MilitaryTrainingRoute.AgencyType(rawValue: agencyTypeStr)

      let orgName = fields[5].trimmingCharacters(in: .whitespaces)
      let station = fields.count > 6 ? fields[6].trimmingCharacters(in: .whitespaces) : ""
      let address = fields.count > 7 ? fields[7].trimmingCharacters(in: .whitespaces) : ""
      let city = fields.count > 8 ? fields[8].trimmingCharacters(in: .whitespaces) : ""
      let stateCode = fields.count > 9 ? fields[9].trimmingCharacters(in: .whitespaces) : ""
      let zipCode = fields.count > 10 ? fields[10].trimmingCharacters(in: .whitespaces) : ""
      let commPhone = fields.count > 11 ? fields[11].trimmingCharacters(in: .whitespaces) : ""
      let DSNPhone = fields.count > 12 ? fields[12].trimmingCharacters(in: .whitespaces) : ""
      let hours = fields.count > 13 ? fields[13].trimmingCharacters(in: .whitespaces) : ""

      let agency = MilitaryTrainingRoute.Agency(
        agencyType: agencyType,
        organizationName: orgName.isEmpty ? nil : orgName,
        station: station.isEmpty ? nil : station,
        address: address.isEmpty ? nil : address,
        city: city.isEmpty ? nil : city,
        stateCode: stateCode.isEmpty ? nil : stateCode,
        zipCode: zipCode.isEmpty ? nil : zipCode,
        commercialPhone: commPhone.isEmpty ? nil : commPhone,
        DSNPhone: DSNPhone.isEmpty ? nil : DSNPhone,
        hours: hours.isEmpty ? nil : hours
      )

      self.routes[key]?.agencies.append(agency)
    }

    // Parse MTR_PT.csv for route points
    // Columns: EFF_DATE(0), ROUTE_TYPE_CODE(1), ROUTE_ID(2), ARTCC(3), ROUTE_PT_SEQ(4),
    // ROUTE_PT_ID(5), NEXT_ROUTE_PT_ID(6), SEGMENT_TEXT(7), LAT_DEG(8), LAT_MIN(9),
    // LAT_SEC(10), LAT_HEMIS(11), LAT_DECIMAL(12), LONG_DEG(13), LONG_MIN(14),
    // LONG_SEC(15), LONG_HEMIS(16), LONG_DECIMAL(17), NAV_ID(18), NAVAID_BEARING(19),
    // NAVAID_DIST(20)
    try await parseCSVFile(filename: "MTR_PT.csv", expectedFieldCount: 21) { fields in
      guard fields.count >= 13 else { return }

      let routeTypeCode = fields[1].trimmingCharacters(in: .whitespaces)
      let routeId = fields[2].trimmingCharacters(in: .whitespaces)
      let key = "\(routeTypeCode)\(routeId)"

      guard !key.isEmpty, self.routes[key] != nil else { return }

      let seqStr = fields[4].trimmingCharacters(in: .whitespaces)
      let pointId = fields[5].trimmingCharacters(in: .whitespaces)
      let segmentText = fields.count > 7 ? fields[7].trimmingCharacters(in: .whitespaces) : ""

      // Use LAT_DECIMAL and LONG_DECIMAL directly (already in decimal degrees)
      let latDecimalStr = fields[12].trimmingCharacters(in: .whitespaces)
      let lonDecimalStr = fields.count > 17 ? fields[17].trimmingCharacters(in: .whitespaces) : ""

      let position: Location? = {
        guard let lat = Double(latDecimalStr),
          let lon = Double(lonDecimalStr)
        else { return nil }
        // Convert decimal degrees to arc-seconds (multiply by 3600)
        return Location(latitudeArcsec: Float(lat * 3600), longitudeArcsec: Float(lon * 3600))
      }()

      let navaidId = fields.count > 18 ? fields[18].trimmingCharacters(in: .whitespaces) : ""
      let bearingStr = fields.count > 19 ? fields[19].trimmingCharacters(in: .whitespaces) : ""
      let distStr = fields.count > 20 ? fields[20].trimmingCharacters(in: .whitespaces) : ""

      let point = MilitaryTrainingRoute.RoutePoint(
        pointId: pointId,
        segmentDescriptionLeading: segmentText.isEmpty ? nil : segmentText,
        segmentDescriptionLeaving: nil,  // CSV format combines into single field
        navaidIdentifier: navaidId.isEmpty ? nil : navaidId,
        navaidBearingDeg: UInt(bearingStr),
        navaidDistanceNM: UInt(distStr),
        position: position,
        sequenceNumber: UInt(seqStr)
      )

      self.routes[key]?.routePoints.append(point)
    }

    // Parse MTR_SOP.csv for standard operating procedures
    // Columns: EFF_DATE(0), ROUTE_TYPE_CODE(1), ROUTE_ID(2), ARTCC(3), SOP_SEQ_NO(4), SOP_TEXT(5)
    try await parseCSVFile(filename: "MTR_SOP.csv", expectedFieldCount: 6) { fields in
      guard fields.count >= 6 else { return }

      let routeTypeCode = fields[1].trimmingCharacters(in: .whitespaces)
      let routeId = fields[2].trimmingCharacters(in: .whitespaces)
      let key = "\(routeTypeCode)\(routeId)"

      guard !key.isEmpty, self.routes[key] != nil else { return }

      let text = fields[5].trimmingCharacters(in: .whitespaces)
      if !text.isEmpty {
        self.routes[key]?.operatingProcedures.append(text)
      }
    }

    // Parse MTR_TERR.csv for terrain following operations
    // Columns: EFF_DATE(0), ROUTE_TYPE_CODE(1), ROUTE_ID(2), ARTCC(3), TERRAIN_SEQ_NO(4),
    // TERRAIN_TEXT(5)
    try await parseCSVFile(filename: "MTR_TERR.csv", expectedFieldCount: 6) { fields in
      guard fields.count >= 6 else { return }

      let routeTypeCode = fields[1].trimmingCharacters(in: .whitespaces)
      let routeId = fields[2].trimmingCharacters(in: .whitespaces)
      let key = "\(routeTypeCode)\(routeId)"

      guard !key.isEmpty, self.routes[key] != nil else { return }

      let text = fields[5].trimmingCharacters(in: .whitespaces)
      if !text.isEmpty {
        self.routes[key]?.terrainFollowingOperations.append(text)
      }
    }

    // Parse MTR_WDTH.csv for route width descriptions
    // Columns: EFF_DATE(0), ROUTE_TYPE_CODE(1), ROUTE_ID(2), ARTCC(3), WIDTH_SEQ_NO(4),
    // WIDTH_TEXT(5)
    try await parseCSVFile(filename: "MTR_WDTH.csv", expectedFieldCount: 6) { fields in
      guard fields.count >= 6 else { return }

      let routeTypeCode = fields[1].trimmingCharacters(in: .whitespaces)
      let routeId = fields[2].trimmingCharacters(in: .whitespaces)
      let key = "\(routeTypeCode)\(routeId)"

      guard !key.isEmpty, self.routes[key] != nil else { return }

      let text = fields[5].trimmingCharacters(in: .whitespaces)
      if !text.isEmpty {
        self.routes[key]?.routeWidthDescriptions.append(text)
      }
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(militaryTrainingRoutes: Array(routes.values))
  }
}
