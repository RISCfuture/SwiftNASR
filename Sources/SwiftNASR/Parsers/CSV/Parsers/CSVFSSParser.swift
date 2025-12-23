import Foundation
import StreamingCSV

/// CSV FSS Parser using declarative transformers like FixedWidthFSSParser
actor CSVFSSParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["FSS_BASE.csv", "FSS_RMK.csv"]

  var FSSes = [String: FSS]()

  private let transformer = CSVTransformer([
    .init("FSS_ID", .string()),
    .init("NAME", .string()),
    .init("VOICE_CALL", .string(nullable: .blank)),
    .init("FSS_FAC_TYPE", .recordEnum(FSS.FSSType.self, nullable: .blank)),
    .init("OPR_HOURS", .string(nullable: .blank)),
    // CSV uses single-char status codes different from enum raw values
    .init("FAC_STATUS", .string(nullable: .blank)),
    .init("PHONE_NO", .string(nullable: .blank)),
    .init("WEA_RADAR_FLAG", .boolean(nullable: .blank)),
    .init("CITY", .string(nullable: .blank)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("LAT_DECIMAL", .float(nullable: .blank)),
    .init("LONG_DECIMAL", .float(nullable: .blank)),
    .init("TOLL_FREE_NO", .string(nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse FSS_BASE.csv
    try await parseCSVFile(
      filename: "FSS_BASE.csv",
      requiredColumns: ["FSS_ID", "NAME"]
    ) { row in
      let t = try self.transformer.applyTo(row)

      // Parse FSS type - default to .FSS if not provided
      let fssType: FSS.FSSType = (try? t[optional: "FSS_FAC_TYPE"]) ?? .FSS

      // Parse status - CSV uses single-char codes different from enum raw values
      let statusCode: String? = try t[optional: "FAC_STATUS"]
      let status: FSS.Status? = try {
        switch statusCode {
          case .none, .some(""): return nil
          case "A": return .operationalIFR
          default: throw ParserError.unknownRecordEnumValue(statusCode!)
        }
      }()

      // Parse location - convert from decimal degrees to arc-seconds
      let location: Location? = {
        let lat: Float? = try? t[optional: "LAT_DECIMAL"]
        let lon: Float? = try? t[optional: "LONG_DECIMAL"]
        if let lat, let lon {
          return Location(
            latitudeArcsec: lat * 3600,
            longitudeArcsec: lon * 3600,
            elevationFtMSL: nil
          )
        }
        return nil
      }()

      // Build remarks array
      var remarks: [String] = []
      if let tollFree: String = try? t[optional: "TOLL_FREE_NO"], !tollFree.isEmpty {
        remarks.append("Toll Free: \(tollFree)")
      }

      let fss = FSS(
        id: try t["FSS_ID"],
        airportId: nil,  // Not in CSV
        name: try t["NAME"],
        radioIdentifier: try t[optional: "VOICE_CALL"],
        type: fssType,
        hoursOfOperation: try t[optional: "OPR_HOURS"] ?? "",
        status: status,
        lowAltEnrouteChartNumber: nil,  // Not in CSV
        frequencies: [],
        commFacilities: [],
        outlets: [],
        navaids: [],
        airportAdvisoryFrequencies: [],
        VOLMETs: [],
        owner: nil,
        ownerName: nil,  // Not in CSV
        operator: .FAA,  // Default to FAA
        operatorName: nil,  // Not in CSV
        hasWeatherRadar: try t[optional: "WEA_RADAR_FLAG"],
        hasEFAS: nil,  // Not in CSV
        flightWatchAvailability: nil,  // Not in CSV
        nearestFSSIdWithTeletype: nil,  // Not in CSV
        city: try t[optional: "CITY"],
        stateName: try t[optional: "STATE_CODE"],
        region: nil,  // Not in CSV
        location: location,
        DFEquipment: nil,
        phoneNumber: try t[optional: "PHONE_NO"],
        remarks: remarks,
        commRemarks: []
      )

      self.FSSes[fss.id] = fss
    }

    // Parse FSS_RMK.csv for additional remarks
    try await parseCSVFile(
      filename: "FSS_RMK.csv",
      requiredColumns: ["FSS_ID", "REMARK"]
    ) { row in
      let fssID = try row["FSS_ID"]
      let remark = try row["REMARK"]

      guard !fssID.isEmpty, !remark.isEmpty else { return }

      if var fss = self.FSSes[fssID] {
        fss.remarks.append(remark)
        self.FSSes[fssID] = fss
      }
    }

    // Note: FSS comm facilities, outlets, etc. are not available in CSV format.
    // These would require additional CSV files that don't exist in the distribution.
  }

  func finish(data: NASRData) async {
    await data.finishParsing(FSSes: Array(FSSes.values))
  }
}
