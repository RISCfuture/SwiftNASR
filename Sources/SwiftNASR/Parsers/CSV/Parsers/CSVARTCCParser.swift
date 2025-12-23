import Foundation
import StreamingCSV

/// CSV ARTCC Parser using declarative transformers like FixedWidthARTCCParser
actor CSVARTCCParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["ATC_BASE.csv", "ATC_RMK.csv", "ATC_SVC.csv"]

  var ARTCCs = [ARTCCKey: ARTCC]()

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse ATC_BASE.csv
    try await parseCSVFile(
      filename: "ATC_BASE.csv",
      requiredColumns: ["FACILITY_ID", "FACILITY_NAME", "FACILITY_TYPE", "CITY"]
    ) { row in
      let facilityID = try row["FACILITY_ID"]
      let facilityName = try row["FACILITY_NAME"]
      let facilityTypeStr = try row["FACILITY_TYPE"]
      let city = try row["CITY"]
      let stateCode = row[ifExists: "STATE_CODE"]
      let ICAOID = row[ifExists: "ICAO_ID"]

      // Parse facility type - skip non-ARTCC records (terminal comm facilities)
      guard let facilityType = try self.parseFacilityType(facilityTypeStr) else { return }

      let center = ARTCC(
        code: facilityID,
        ICAOID: ICAOID,
        type: facilityType,
        name: facilityName,
        alternateName: nil,
        locationName: city,
        stateCode: stateCode,
        location: nil  // Would need to parse lat/lon if available
      )

      let key = ARTCCKey(center: center)
      self.ARTCCs[key] = center
    }

    // Parse ATC_RMK.csv for remarks
    try await parseCSVFile(
      filename: "ATC_RMK.csv",
      requiredColumns: ["FACILITY_TYPE", "FACILITY_ID", "CITY", "REMARK"]
    ) { row in
      let facilityTypeStr = try row["FACILITY_TYPE"]
      let facilityID = try row["FACILITY_ID"]
      let city = try row["CITY"]
      let remark = try row["REMARK"]

      // Only process remarks for ARTCC facility types (skip terminal comm facilities)
      guard let facilityType = try self.parseFacilityType(facilityTypeStr) else { return }

      guard !facilityID.isEmpty, !remark.isEmpty else { return }

      let key = ARTCCKey(ID: facilityID, location: city, type: facilityType)
      if var center = self.ARTCCs[key] {
        center.remarks.append(.general(remark))
        self.ARTCCs[key] = center
      }
    }

    // Parse ATC_SVC.csv for services
    try await parseCSVFile(
      filename: "ATC_SVC.csv",
      requiredColumns: ["FACILITY_TYPE", "FACILITY_ID", "CITY", "CTL_SVC"]
    ) { row in
      let facilityTypeStr = try row["FACILITY_TYPE"],
        facilityID = try row["FACILITY_ID"],
        city = try row["CITY"],
        service = try row["CTL_SVC"]

      // Only process services for ARTCC facility types (skip terminal comm facilities)
      guard let facilityType = try self.parseFacilityType(facilityTypeStr) else { return }

      guard !facilityID.isEmpty, !service.isEmpty else { return }

      let key = ARTCCKey(ID: facilityID, location: city, type: facilityType)
      if var center = self.ARTCCs[key] {
        center.services.append(service)
        self.ARTCCs[key] = center
      }
    }

    // Note: ATC_ATIS.csv does not contain ARTCC facility types.
    // ATIS (Automatic Terminal Information Service) is an airport service.
  }

  func finish(data: NASRData) async {
    await data.finishParsing(ARTCCs: Array(ARTCCs.values))
  }

  /// Parses ARTCC facility type from the CSV facility type string.
  ///
  /// Per aff_rf.txt layout, valid ARTCC facility types are:
  /// - ARTCC: Air Route Traffic Control Center
  /// - CERAP: Center Radar Approach Control Facility
  /// - RCAG: Remote Communications Air/Ground
  /// - ARSR: Air Route Surveillance Radar (removed from distribution as of 12/29/2022)
  /// - SECRA: Secondary Radar (removed from distribution as of 12/29/2022)
  ///
  /// Returns nil for terminal communication facility types (TRACON, ATCT, etc.)
  /// which should be handled by CSVTerminalCommFacilityParser instead.
  private func parseFacilityType(_ type: String) throws -> ARTCC.FacilityType? {
    let upperType = type.uppercased().trimmingCharacters(in: .whitespaces).replacingOccurrences(
      of: "\"",
      with: ""
    )

    switch upperType {
      case "ARTCC", "CENTER":
        return .ARTCC
      case "CERAP":
        return .CERAP
      case "RCAG":
        return .RCAG
      case "SECRA":
        return .SECRA
      case "ARSR":
        return .ARSR
      // Terminal communication facilities - not ARTCC types, skip these records
      case "TRACON", "ATCT", "NON-ATCT", "ATCT-TRACON", "ATCT-A/C",
        "ATCT-RAPCON", "ATCT-RATCF", "ATCT-TRACAB", "TRACAB":
        return nil
      default:
        throw ParserError.unknownRecordEnumValue(type)
    }
  }
}
