import Foundation
import StreamingCSV

/// CSV Terminal Communications Facility Parser.
///
/// The legacy `TWR.txt` subscriber file was deconstructed by the FAA into several CSV
/// files. The base facility, services, ATIS, and remarks come from `ATC_*.csv`; the
/// radar (legacy TWR5), military operations (legacy TWR1/2/6), and class-airspace
/// (legacy TWR8) data are folded in from `RDR.csv`, `MIL_OPS.csv`, and `CLS_ARSP.csv`
/// respectively, so the CSV ``TerminalCommFacility`` matches the TXT representation.
actor CSVTerminalCommFacilityParser: CSVParser, DiagnosingParser {
  static let type = RecordType.terminalCommFacilities

  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = [
    "ATC_BASE.csv", "ATC_SVC.csv", "ATC_ATIS.csv", "ATC_RMK.csv",
    "RDR.csv", "MIL_OPS.csv", "CLS_ARSP.csv"
  ]

  var facilities = [String: TerminalCommFacility]()
  var pendingDiagnostics = [RecordParseError]()

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse ATC_BASE.csv for base facility data
    try await parseCSVFile(
      filename: "ATC_BASE.csv",
      requiredColumns: ["FACILITY_ID", "FACILITY_TYPE"]
    ) { row in
      let facilityID = try row["FACILITY_ID"]
      guard !facilityID.isEmpty else {
        throw ParserError.missingRequiredField(field: "facilityId", recordType: "ATC_BASE")
      }

      let facility = TerminalCommFacility(
        facilityId: facilityID,
        airportSiteNumber: try row.optional("SITE_NO"),
        effectiveDateComponents: self.parseYYYYMMDDDate(try row["EFF_DATE"]),
        regionCode: try row.optional("REGION_CODE"),
        stateName: nil,  // Not in CSV BASE
        stateCode: try row.optional("STATE_CODE"),
        city: try row.optional("CITY"),
        airportName: try row.optional("FACILITY_NAME"),
        position: nil,  // Not directly in CSV BASE
        tieInFSSId: nil,
        tieInFSSName: nil,
        facilityType: diagnose(
          TerminalCommFacility.FacilityType.self,
          try row.optional("FACILITY_TYPE"),
          field: "facilityType",
          id: facilityID
        ),
        hoursOfOperation: nil,
        operationRegularity: nil,
        masterAirportId: nil,
        masterAirportName: nil,
        directionFindingEquipment: nil,
        offAirportFacilityName: nil,
        offAirportCity: nil,
        offAirportState: nil,
        offAirportStateCode: nil,
        offAirportRegionCode: nil,
        ASRPosition: nil,
        DFPosition: nil,
        towerOperator: try row.optional("TWR_OPERATOR_CODE"),
        militaryOperator: nil,
        primaryApproachOperator: try row.optional("APCH_P_PROVIDER"),
        secondaryApproachOperator: try row.optional("APCH_S_PROVIDER"),
        primaryDepartureOperator: try row.optional("DEP_P_PROVIDER"),
        secondaryDepartureOperator: try row.optional("DEP_S_PROVIDER"),
        towerRadioCall: try row.optional("TWR_CALL"),
        militaryRadioCall: nil,
        primaryApproachRadioCall: try row.optional("PRIMARY_APCH_RADIO_CALL"),
        secondaryApproachRadioCall: try row.optional("SECONDARY_APCH_RADIO_CALL"),
        primaryDepartureRadioCall: try row.optional("PRIMARY_DEP_RADIO_CALL"),
        secondaryDepartureRadioCall: try row.optional("SECONDARY_DEP_RADIO_CALL"),
        pmsvHours: nil,
        macpHours: nil,
        militaryOperationsHours: nil,
        primaryApproachHours: try row.optional("CTL_PRVDING_HRS"),
        secondaryApproachHours: try row.optional("SECONDARY_CTL_PRVDING_HRS"),
        primaryDepartureHours: nil,
        secondaryDepartureHours: nil,
        towerHours: try row.optional("TWR_HRS")
      )

      self.facilities[facilityID] = facility
    }

    // Parse ATC_SVC.csv for services
    try await parseCSVFile(
      filename: "ATC_SVC.csv",
      requiredColumns: ["FACILITY_ID", "CTL_SVC"]
    ) { row in
      let facilityID = try row["FACILITY_ID"]
      guard !facilityID.isEmpty else {
        throw ParserError.missingRequiredField(field: "facilityId", recordType: "ATC_SVC")
      }
      guard self.facilities[facilityID] != nil else {
        throw ParserError.unknownParentRecord(
          parentType: "TerminalCommFacility",
          parentID: facilityID,
          childType: "service"
        )
      }

      let service = try row["CTL_SVC"]
      if !service.isEmpty {
        // Append to existing services or set new
        if let existing = self.facilities[facilityID]?.masterAirportServices {
          self.facilities[facilityID]?.masterAirportServices = "\(existing); \(service)"
        } else {
          self.facilities[facilityID]?.masterAirportServices = service
        }
      }
    }

    // Parse ATC_ATIS.csv for ATIS data
    try await parseCSVFile(
      filename: "ATC_ATIS.csv",
      requiredColumns: ["FACILITY_ID", "ATIS_NO"]
    ) { row in
      let facilityID = try row["FACILITY_ID"]
      guard !facilityID.isEmpty else {
        throw ParserError.missingRequiredField(field: "facilityId", recordType: "ATC_ATIS")
      }
      guard self.facilities[facilityID] != nil else {
        throw ParserError.unknownParentRecord(
          parentType: "TerminalCommFacility",
          parentID: facilityID,
          childType: "ATIS"
        )
      }

      guard let serialNumber = UInt(try row["ATIS_NO"]) else {
        throw ParserError.missingRequiredField(field: "serialNumber", recordType: "ATC_ATIS")
      }

      let atis = TerminalCommFacility.ATIS(
        serialNumber: serialNumber,
        hours: try row.optional("ATIS_HRS"),
        description: try row.optional("DESCRIPTION"),
        phoneNumber: try row.optional("ATIS_PHONE_NO")
      )

      self.facilities[facilityID]?.ATISInfo.append(atis)
    }

    // Parse ATC_RMK.csv for remarks
    try await parseCSVFile(
      filename: "ATC_RMK.csv",
      requiredColumns: ["FACILITY_ID", "REMARK"]
    ) { row in
      let facilityID = try row["FACILITY_ID"]
      guard !facilityID.isEmpty else {
        throw ParserError.missingRequiredField(field: "facilityId", recordType: "ATC_RMK")
      }
      guard self.facilities[facilityID] != nil else {
        throw ParserError.unknownParentRecord(
          parentType: "TerminalCommFacility",
          parentID: facilityID,
          childType: "remark"
        )
      }

      let remark = try row["REMARK"]
      if !remark.isEmpty {
        self.facilities[facilityID]?.remarks.append(remark)
      }
    }

    // The FAA split the legacy TWR radar/military/airspace data into separate CSV
    // files. Fold them back into the facilities parsed above. RDR is keyed by
    // FACILITY_ID; MIL_OPS and CLS_ARSP are keyed by SITE_NO.
    let siteToFacility = Dictionary(
      facilities.values.compactMap { facility -> (String, String)? in
        guard let siteNumber = facility.airportSiteNumber, !siteNumber.isEmpty else { return nil }
        return (siteNumber, facility.facilityId)
      },
      uniquingKeysWith: { first, _ in first }
    )

    try await parseRadar()
    try await parseMilitaryOperations(siteToFacility: siteToFacility)
    try await parseClassAirspace(siteToFacility: siteToFacility)
  }

  func finish(data: NASRData) async {
    await data.finishParsing(terminalCommFacilities: Array(facilities.values))
  }

  // MARK: - Folded record files

  /// Parses `RDR.csv` (legacy TWR5) and appends radar equipment to each facility,
  /// matched by `FACILITY_ID`. Rows referencing an unknown facility are recorded as
  /// dropped-row diagnostics.
  private func parseRadar() async throws {
    try await parseCSVFile(
      filename: "RDR.csv",
      requiredColumns: ["FACILITY_ID", "RADAR_TYPE"]
    ) { row in
      let facilityID = try row["FACILITY_ID"]
      guard self.facilities[facilityID] != nil else {
        throw ParserError.unknownParentRecord(
          parentType: "TerminalCommFacility",
          parentID: facilityID,
          childType: "radar"
        )
      }

      let radarType = try row["RADAR_TYPE"]
      guard !radarType.isEmpty else { return }

      let equipment = TerminalCommFacility.Radar.RadarEquipment(
        radarType: radarType,
        hours: try row.optional("RADAR_HRS")
      )

      if self.facilities[facilityID]?.radar == nil {
        self.facilities[facilityID]?.radar = TerminalCommFacility.Radar(
          primaryApproachRadar: nil,
          secondaryApproachRadar: nil,
          primaryDepartureRadar: nil,
          secondaryDepartureRadar: nil
        )
      }
      self.facilities[facilityID]?.radar?.equipment.append(equipment)
    }
  }

  /// Parses `MIL_OPS.csv` (legacy TWR1/2/6) and merges military-operations data into
  /// each facility, matched by `SITE_NO`. Rows referencing an unknown site are recorded
  /// as dropped-row diagnostics.
  private func parseMilitaryOperations(siteToFacility: [String: String]) async throws {
    try await parseCSVFile(
      filename: "MIL_OPS.csv",
      requiredColumns: ["SITE_NO"]
    ) { row in
      let siteNumber = try row["SITE_NO"]
      guard let facilityID = siteToFacility[siteNumber] else {
        throw ParserError.unknownParentRecord(
          parentType: "TerminalCommFacility",
          parentID: siteNumber,
          childType: "military operations"
        )
      }

      self.facilities[facilityID]?.militaryOperator = self.militaryOperatorName(
        try row.optional("MIL_OPS_OPER_CODE"),
        siteNumber: siteNumber
      )
      self.facilities[facilityID]?.militaryRadioCall = try row.optional("MIL_OPS_CALL")
      self.facilities[facilityID]?.militaryOperationsHours = try row.optional("MIL_OPS_HRS")
      self.facilities[facilityID]?.macpHours = try row.optional("AMCP_HRS")
      self.facilities[facilityID]?.pmsvHours = try row.optional("PMSV_HRS")
    }
  }

  /// Parses `CLS_ARSP.csv` (legacy TWR8) and merges class-airspace data into each
  /// facility, matched by `SITE_NO`. Rows referencing an unknown site are recorded as
  /// dropped-row diagnostics.
  private func parseClassAirspace(siteToFacility: [String: String]) async throws {
    try await parseCSVFile(
      filename: "CLS_ARSP.csv",
      requiredColumns: ["SITE_NO"]
    ) { row in
      let siteNumber = try row["SITE_NO"]
      guard let facilityID = siteToFacility[siteNumber] else {
        throw ParserError.unknownParentRecord(
          parentType: "TerminalCommFacility",
          parentID: siteNumber,
          childType: "class airspace"
        )
      }

      let airspace = TerminalCommFacility.Airspace(
        classB: try ParserHelpers.parseYNFlagRequired(
          row.optional("CLASS_B_AIRSPACE"),
          fieldName: "classB"
        ),
        classC: try ParserHelpers.parseYNFlagRequired(
          row.optional("CLASS_C_AIRSPACE"),
          fieldName: "classC"
        ),
        classD: try ParserHelpers.parseYNFlagRequired(
          row.optional("CLASS_D_AIRSPACE"),
          fieldName: "classD"
        ),
        classE: try ParserHelpers.parseYNFlagRequired(
          row.optional("CLASS_E_AIRSPACE"),
          fieldName: "classE"
        ),
        hours: try row.optional("AIRSPACE_HRS")
      )
      self.facilities[facilityID]?.airspace = airspace
    }
  }

  // MARK: - Helper methods

  /// Decodes a `MIL_OPS_OPER_CODE` into the agency name used by the TXT format. An
  /// unknown non-blank code records a field-level diagnostic and returns `nil`.
  private func militaryOperatorName(_ code: String?, siteNumber: String) -> String? {
    guard let code, !code.isEmpty else { return nil }
    switch code.uppercased() {
      case "A": return "U.S. AIR FORCE"
      case "C": return "U.S. COAST GUARD"
      case "F": return "FEDERAL AVIATION ADMIN"
      case "N": return "U.S. NAVY"
      case "R": return "U.S. ARMY"
      default:
        recordFieldError(
          field: "militaryOperator",
          value: code,
          id: siteNumber,
          underlying: ParserError.unknownRecordEnumValue(code)
        )
        return nil
    }
  }

  private func parseYYYYMMDDDate(_ string: String) -> DateComponents? {
    let trimmed = string.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    // Format: YYYY/MM/DD
    let parts = trimmed.split(separator: "/")
    guard parts.count == 3,
      let year = Int(parts[0]),
      let month = Int(parts[1]),
      let day = Int(parts[2])
    else { return nil }

    return DateComponents(year: year, month: month, day: day)
  }
}
