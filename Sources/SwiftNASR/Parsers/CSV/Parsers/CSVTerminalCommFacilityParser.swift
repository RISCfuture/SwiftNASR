import Foundation
import StreamingCSV

/// CSV Terminal Communications Facility Parser for parsing ATC_BASE.csv, ATC_SVC.csv, ATC_ATIS.csv, ATC_RMK.csv
actor CSVTerminalCommFacilityParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["ATC_BASE.csv", "ATC_SVC.csv", "ATC_ATIS.csv", "ATC_RMK.csv"]

  var facilities = [String: TerminalCommFacility]()

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
        facilityType: TerminalCommFacility.FacilityType.for(try row["FACILITY_TYPE"]),
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
  }

  func finish(data: NASRData) async {
    await data.finishParsing(terminalCommFacilities: Array(facilities.values))
  }

  // MARK: - Helper methods

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
