import Foundation
import StreamingCSV
import ZIPFoundation

/// CSV FSS Parser using declarative transformers like FixedWidthFSSParser
class CSVFSSParser: CSVParser {
  var csvDirectory = URL(fileURLWithPath: "/")
  var FSSes = [String: FSS]()

  // CSV field mapping based on FSS_BASE.csv headers
  // Maps CSV column indices to transformer array positions
  private let csvFieldMapping: [Int] = [
    1,  // 0: FSS_ID -> ID
    2,  // 1: NAME -> name
    5,  // 2: VOICE_CALL -> radioIdentifier
    4,  // 3: FSS_FAC_TYPE -> type
    19,  // 4: OPR_HOURS -> hoursOfOperation
    20,  // 5: FAC_STATUS -> status
    -1,  // 6: lowAltEnrouteChartNumber - not in CSV
    23,  // 7: PHONE_NO -> phoneNumber
    22,  // 8: WEA_RADAR_FLAG -> hasWeatherRadar
    -1,  // 9: hasEFAS - not in CSV
    -1,  // 10: flightWatchAvailability - not in CSV
    -1,  // 11: nearestFSSIDWithTeletype - not in CSV
    6,  // 12: CITY -> city
    7,  // 13: STATE_CODE -> stateName
    -1,  // 14: region - not in CSV
    13,  // 15: LAT_DECIMAL -> latitude
    18,  // 16: LONG_DECIMAL -> longitude
    -1,  // 17: DFEquipment - not in CSV
    -1,  // 18: airportID - not in CSV
    -1,  // 19: owner - not in CSV
    -1,  // 20: ownerName - not in CSV
    -1,  // 21: operator - not in CSV (will default)
    -1,  // 22: operatorName - not in CSV
    24  // 23: TOLL_FREE_NO -> toll free number (stored as remark)
  ]

  private let transformer = CSVTransformer([
    .string(),  // 0: ID
    .string(),  // 1: name
    .string(nullable: .blank),  // 2: radioIdentifier
    .string(nullable: .blank),  // 3: type (as string)
    .string(nullable: .blank),  // 4: hoursOfOperation
    .string(nullable: .blank),  // 5: status (as string)
    .string(nullable: .blank),  // 6: lowAltEnrouteChartNumber
    .string(nullable: .blank),  // 7: phoneNumber
    .boolean(nullable: .blank),  // 8: hasWeatherRadar
    .boolean(nullable: .blank),  // 9: hasEFAS
    .string(nullable: .blank),  // 10: flightWatchAvailability
    .string(nullable: .blank),  // 11: nearestFSSIDWithTeletype
    .string(nullable: .blank),  // 12: city
    .string(nullable: .blank),  // 13: stateName
    .string(nullable: .blank),  // 14: region
    .float(nullable: .blank),  // 15: latitude
    .float(nullable: .blank),  // 16: longitude
    .string(nullable: .blank),  // 17: DFEquipment (as string)
    .string(nullable: .blank),  // 18: airportID
    .string(nullable: .blank),  // 19: owner (as string)
    .string(nullable: .blank),  // 20: ownerName
    .string(nullable: .blank),  // 21: operator (as string)
    .string(nullable: .blank),  // 22: operatorName
    .string(nullable: .blank)  // 23: toll free number
  ])

  func prepare(distribution: Distribution) throws {
    // Set the CSV directory for CSV distributions
    if let dirDist = distribution as? DirectoryDistribution {
      csvDirectory = dirDist.location
    } else if let archiveDist = distribution as? ArchiveFileDistribution {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        "SwiftNASR_CSV_\(UUID().uuidString)"
      )
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      try FileManager.default.unzipItem(at: archiveDist.location, to: tempDir)
      csvDirectory = tempDir
    }
  }

  func parse(data _: Data) async throws {
    // Parse FSS_BASE.csv
    try await parseCSVFile(filename: "FSS_BASE.csv", expectedFieldCount: 25) { fields in
      guard fields.count >= 20 else { return }

      // Map CSV fields to transformer indices
      var mappedFields = [String](repeating: "", count: 24)

      for (transformerIndex, csvIndex) in csvFieldMapping.enumerated() {
        if csvIndex >= 0 && csvIndex < fields.count {
          mappedFields[transformerIndex] = fields[csvIndex]
        }
      }

      let transformedValues = try self.transformer.applyTo(mappedFields, indices: Array(0..<24))

      // Parse FSS type
      let fssType: FSS.FSSType = {
        if let typeStr = transformedValues[3] as? String {
          if let parsed = try? ParserHelpers.raw(typeStr, toEnum: FSS.FSSType.self) {
            return parsed
          }
        }
        // Default to FSS if unable to parse
        return .FSS
      }()

      // Parse status
      let status: FSS.Status? = {
        if let statusStr = transformedValues[5] as? String {
          return try? ParserHelpers.raw(statusStr, toEnum: FSS.Status.self)
        }
        return nil
      }()

      // Parse location - convert from decimal degrees to arc-seconds
      let location: Location? = {
        if let lat = transformedValues[15] as? Float,
          let lon = transformedValues[16] as? Float
        {
          return Location(
            latitudeArcsec: lat * 3600,
            longitudeArcsec: lon * 3600,
            elevationFtMSL: nil
          )
        }
        return nil
      }()

      // Parse operator - default to FAA if not specified
      let `operator`: FSS.Operator = {
        if let opStr = transformedValues[21] as? String {
          if let parsed = try? ParserHelpers.raw(opStr, toEnum: FSS.Operator.self) {
            return parsed
          }
        }
        return .FAA
      }()

      // Build remarks array
      var remarks: [String] = []
      if let tollFree = transformedValues[23] as? String, !tollFree.isEmpty {
        remarks.append("Toll Free: \(tollFree)")
      }

      let fss = FSS(
        id: transformedValues[0] as! String,
        airportId: transformedValues[18] as? String,
        name: transformedValues[1] as! String,
        radioIdentifier: transformedValues[2] as? String,
        type: fssType,
        hoursOfOperation: transformedValues[4] as? String ?? "",
        status: status,
        lowAltEnrouteChartNumber: transformedValues[6] as? String,
        frequencies: [],
        commFacilities: [],
        outlets: [],
        navaids: [],
        airportAdvisoryFrequencies: [],
        VOLMETs: [],
        owner: nil,
        ownerName: transformedValues[20] as? String,
        operator: `operator`,
        operatorName: transformedValues[22] as? String,
        hasWeatherRadar: transformedValues[8] as? Bool,
        hasEFAS: transformedValues[9] as? Bool,
        flightWatchAvailability: transformedValues[10] as? String,
        nearestFSSIdWithTeletype: transformedValues[11] as? String,
        city: transformedValues[12] as? String,
        stateName: transformedValues[13] as? String,
        region: transformedValues[14] as? String,
        location: location,
        DFEquipment: nil,
        phoneNumber: transformedValues[7] as? String,
        remarks: remarks,
        commRemarks: []
      )

      self.FSSes[fss.id] = fss
    }

    // Parse FSS_RMK.csv for additional remarks
    try await parseCSVFile(filename: "FSS_RMK.csv", expectedFieldCount: 9) { fields in
      guard fields.count >= 9 else { return }

      let fssID = fields[1].trimmingCharacters(in: .whitespaces)
      let remark = fields[8].trimmingCharacters(in: .whitespaces)

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
