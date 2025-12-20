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
    try await parseCSVFile(filename: "ATC_BASE.csv", expectedFieldCount: 30) { fields in
      guard fields.count >= 10 else {
        throw ParserError.truncatedRecord(
          recordType: "ATC_BASE",
          expectedMinLength: 10,
          actualLength: fields.count
        )
      }

      let facilityID = fields[5].trimmingCharacters(in: .whitespaces)
      guard !facilityID.isEmpty else {
        throw ParserError.missingRequiredField(field: "facilityId", recordType: "ATC_BASE")
      }

      let effDate = self.parseYYYYMMDDDate(fields[0])
      let facilityTypeStr = fields[3].trimmingCharacters(in: .whitespaces)
      let facilityType = TerminalCommFacility.FacilityType.for(facilityTypeStr)

      let facility = TerminalCommFacility(
        facilityId: facilityID,
        airportSiteNumber: fields[1].trimmingCharacters(in: .whitespaces).isEmpty
          ? nil : fields[1].trimmingCharacters(in: .whitespaces),
        effectiveDateComponents: effDate,
        regionCode: fields.count > 10
          ? (fields[10].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[10].trimmingCharacters(in: .whitespaces)) : nil,
        stateName: nil,  // Not in CSV BASE
        stateCode: fields[4].trimmingCharacters(in: .whitespaces).isEmpty
          ? nil : fields[4].trimmingCharacters(in: .whitespaces),
        city: fields[6].trimmingCharacters(in: .whitespaces).isEmpty
          ? nil : fields[6].trimmingCharacters(in: .whitespaces),
        airportName: fields.count > 9
          ? (fields[9].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[9].trimmingCharacters(in: .whitespaces)) : nil,
        position: nil,  // Not directly in CSV BASE
        tieInFSSId: nil,
        tieInFSSName: nil,
        facilityType: facilityType,
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
        towerOperator: fields.count > 11
          ? (fields[11].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[11].trimmingCharacters(in: .whitespaces)) : nil,
        militaryOperator: nil,
        primaryApproachOperator: fields.count > 15
          ? (fields[15].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[15].trimmingCharacters(in: .whitespaces)) : nil,
        secondaryApproachOperator: fields.count > 18
          ? (fields[18].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[18].trimmingCharacters(in: .whitespaces)) : nil,
        primaryDepartureOperator: fields.count > 21
          ? (fields[21].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[21].trimmingCharacters(in: .whitespaces)) : nil,
        secondaryDepartureOperator: fields.count > 24
          ? (fields[24].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[24].trimmingCharacters(in: .whitespaces)) : nil,
        towerRadioCall: fields.count > 12
          ? (fields[12].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[12].trimmingCharacters(in: .whitespaces)) : nil,
        militaryRadioCall: nil,
        primaryApproachRadioCall: fields.count > 14
          ? (fields[14].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[14].trimmingCharacters(in: .whitespaces)) : nil,
        secondaryApproachRadioCall: fields.count > 17
          ? (fields[17].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[17].trimmingCharacters(in: .whitespaces)) : nil,
        primaryDepartureRadioCall: fields.count > 20
          ? (fields[20].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[20].trimmingCharacters(in: .whitespaces)) : nil,
        secondaryDepartureRadioCall: fields.count > 23
          ? (fields[23].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[23].trimmingCharacters(in: .whitespaces)) : nil,
        pmsvHours: nil,
        macpHours: nil,
        militaryOperationsHours: nil,
        primaryApproachHours: fields.count > 28
          ? (fields[28].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[28].trimmingCharacters(in: .whitespaces)) : nil,
        secondaryApproachHours: fields.count > 29
          ? (fields[29].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[29].trimmingCharacters(in: .whitespaces)) : nil,
        primaryDepartureHours: nil,
        secondaryDepartureHours: nil,
        towerHours: fields.count > 13
          ? (fields[13].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[13].trimmingCharacters(in: .whitespaces)) : nil
      )

      self.facilities[facilityID] = facility
    }

    // Parse ATC_SVC.csv for services
    try await parseCSVFile(filename: "ATC_SVC.csv", expectedFieldCount: 9) { fields in
      guard fields.count >= 9 else {
        throw ParserError.truncatedRecord(
          recordType: "ATC_SVC",
          expectedMinLength: 9,
          actualLength: fields.count
        )
      }

      let facilityID = fields[5].trimmingCharacters(in: .whitespaces)
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

      let service = fields[8].trimmingCharacters(in: .whitespaces)
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
    try await parseCSVFile(filename: "ATC_ATIS.csv", expectedFieldCount: 12) { fields in
      guard fields.count >= 11 else {
        throw ParserError.truncatedRecord(
          recordType: "ATC_ATIS",
          expectedMinLength: 11,
          actualLength: fields.count
        )
      }

      let facilityID = fields[5].trimmingCharacters(in: .whitespaces)
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

      guard let serialNumber = UInt(fields[8].trimmingCharacters(in: .whitespaces)) else {
        throw ParserError.missingRequiredField(field: "serialNumber", recordType: "ATC_ATIS")
      }

      let atis = TerminalCommFacility.ATIS(
        serialNumber: serialNumber,
        hours: fields[10].trimmingCharacters(in: .whitespaces).isEmpty
          ? nil : fields[10].trimmingCharacters(in: .whitespaces),
        description: fields.count > 9
          ? (fields[9].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[9].trimmingCharacters(in: .whitespaces)) : nil,
        phoneNumber: fields.count > 11
          ? (fields[11].trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : fields[11].trimmingCharacters(in: .whitespaces)) : nil
      )

      self.facilities[facilityID]?.ATISInfo.append(atis)
    }

    // Parse ATC_RMK.csv for remarks
    try await parseCSVFile(filename: "ATC_RMK.csv", expectedFieldCount: 13) { fields in
      guard fields.count >= 13 else {
        throw ParserError.truncatedRecord(
          recordType: "ATC_RMK",
          expectedMinLength: 13,
          actualLength: fields.count
        )
      }

      let facilityID = fields[5].trimmingCharacters(in: .whitespaces)
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

      let remark = fields[12].trimmingCharacters(in: .whitespaces)
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
