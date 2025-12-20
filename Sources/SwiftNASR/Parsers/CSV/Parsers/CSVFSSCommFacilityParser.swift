import Foundation
import StreamingCSV

/// CSV Parser for COM (FSS Communications Facilities) files.
///
/// Parses FSS communication outlet data from `COM.csv`.
/// Note: The CSV format does not include frequencies, navaid position data,
/// owner/operator info, charts, or time zone that are available in the TXT format.
actor CSVFSSCommFacilityParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["COM.csv"]

  var facilities = [FSSCommFacility]()

  // CSV field indices from COM_CSV_DATA_STRUCTURE.csv:
  // 0: EFF_DATE, 1: COMM_LOC_ID, 2: COMM_TYPE, 3: NAV_ID, 4: NAV_TYPE,
  // 5: CITY, 6: STATE_CODE, 7: REGION_CODE, 8: COUNTRY_CODE, 9: COMM_OUTLET_NAME,
  // 10-14: LAT (DEG/MIN/SEC/HEMIS/DECIMAL), 15-19: LONG (DEG/MIN/SEC/HEMIS/DECIMAL),
  // 20: FACILITY_ID, 21: FACILITY_NAME, 22: ALT_FSS_ID, 23: ALT_FSS_NAME,
  // 24: OPR_HRS, 25: COMM_STATUS_CODE, 26: COMM_STATUS_DATE, 27: REMARK

  private let transformer = CSVTransformer([
    .dateComponents(format: .yearMonthDaySlash, nullable: .blank),  // 0: EFF_DATE
    .string(nullable: .blank),  // 1: COMM_LOC_ID
    .string(nullable: .blank),  // 2: COMM_TYPE
    .string(nullable: .blank),  // 3: NAV_ID
    .string(nullable: .blank),  // 4: NAV_TYPE
    .string(nullable: .blank),  // 5: CITY
    .string(nullable: .blank),  // 6: STATE_CODE
    .string(nullable: .blank),  // 7: REGION_CODE
    .string(nullable: .blank),  // 8: COUNTRY_CODE
    .string(nullable: .blank),  // 9: COMM_OUTLET_NAME
    .unsignedInteger(nullable: .blank),  // 10: LAT_DEG
    .unsignedInteger(nullable: .blank),  // 11: LAT_MIN
    .float(nullable: .blank),  // 12: LAT_SEC
    .string(nullable: .blank),  // 13: LAT_HEMIS
    .float(nullable: .blank),  // 14: LAT_DECIMAL
    .unsignedInteger(nullable: .blank),  // 15: LONG_DEG
    .unsignedInteger(nullable: .blank),  // 16: LONG_MIN
    .float(nullable: .blank),  // 17: LONG_SEC
    .string(nullable: .blank),  // 18: LONG_HEMIS
    .float(nullable: .blank),  // 19: LONG_DECIMAL
    .string(nullable: .blank),  // 20: FACILITY_ID
    .string(nullable: .blank),  // 21: FACILITY_NAME
    .string(nullable: .blank),  // 22: ALT_FSS_ID
    .string(nullable: .blank),  // 23: ALT_FSS_NAME
    .string(nullable: .blank),  // 24: OPR_HRS
    .string(nullable: .blank),  // 25: COMM_STATUS_CODE
    .dateComponents(format: .yearMonthDaySlash, nullable: .blank),  // 26: COMM_STATUS_DATE
    .string(nullable: .blank)  // 27: REMARK
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    try await parseCSVFile(filename: "COM.csv", expectedFieldCount: 28) { fields in
      guard fields.count >= 20 else { return }

      let transformedValues = try self.transformer.applyTo(fields, indices: Array(0..<28))

      let outletID = (transformedValues[1] as? String ?? "").trimmingCharacters(in: .whitespaces)
      guard !outletID.isEmpty else { return }

      // Parse outlet type
      let outletTypeStr = (transformedValues[2] as? String ?? "").trimmingCharacters(
        in: .whitespaces
      )
      let outletType = FSSCommFacility.OutletType(rawValue: outletTypeStr)

      // Parse navaid type from full name (CSV has full name like "VOR/DME" not short code)
      let navaidTypeStr = (transformedValues[4] as? String ?? "").trimmingCharacters(
        in: .whitespaces
      )
      let navaidType: Navaid.FacilityType? =
        if navaidTypeStr.isEmpty {
          nil
        } else {
          Navaid.FacilityType.for(navaidTypeStr)
        }

      // Parse outlet position from decimal degrees
      let outletPosition: Location? = {
        if let lat = transformedValues[14] as? Float,
          let lon = transformedValues[19] as? Float
        {
          // Convert decimal degrees to arc-seconds
          return Location(
            latitudeArcsec: lat * 3600,
            longitudeArcsec: lon * 3600,
            elevationFtMSL: nil
          )
        }
        return nil
      }()

      // Parse status - CSV uses single character code
      let statusCode = (transformedValues[25] as? String ?? "").trimmingCharacters(in: .whitespaces)
      let status: FSS.Status? =
        switch statusCode {
          case "A": .operationalIFR
          default: nil
        }

      let facility = FSSCommFacility(
        outletIdentifier: outletID,
        outletType: outletType,
        navaidIdentifier: transformedValues[3] as? String,
        navaidType: navaidType,
        navaidCity: nil,  // Not in CSV format
        navaidState: nil,  // Not in CSV format
        navaidName: nil,  // Not in CSV format
        navaidPosition: nil,  // Not in CSV format
        outletCity: transformedValues[5] as? String,
        outletState: transformedValues[6] as? String,
        regionName: nil,  // Not in CSV format
        regionCode: transformedValues[7] as? String,
        outletPosition: outletPosition,
        outletCall: transformedValues[9] as? String,
        frequencies: [],  // Not in CSV format
        FSSIdentifier: transformedValues[20] as? String,
        FSSName: transformedValues[21] as? String,
        alternateFSSIdentifier: transformedValues[22] as? String,
        alternateFSSName: transformedValues[23] as? String,
        operationalHours: transformedValues[24] as? String,
        ownerCode: nil,  // Not in CSV format
        ownerName: nil,  // Not in CSV format
        operatorCode: nil,  // Not in CSV format
        operatorName: nil,  // Not in CSV format
        charts: [],  // Not in CSV format
        timeZone: nil,  // Not in CSV format
        status: status,
        statusDateComponents: transformedValues[26] as? DateComponents
      )

      self.facilities.append(facility)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(FSSCommFacilities: facilities)
  }
}
