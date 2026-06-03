import Foundation
import StreamingCSV

/// CSV Parser for COM (FSS Communications Facilities) files.
///
/// Parses FSS communication outlet data from `COM.csv`.
/// Note: The CSV format does not include frequencies, navaid position data,
/// owner/operator info, charts, or time zone that are available in the TXT format.
actor CSVFSSCommFacilityParser: CSVParser, DiagnosingParser {
  static let type = RecordType.FSSCommFacilities
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["COM.csv"]

  var facilities = [FSSCommFacility]()
  var pendingDiagnostics = [RecordParseError]()

  private let transformer = CSVTransformer([
    .init("EFF_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("COMM_LOC_ID", .string(nullable: .blank)),
    .init("COMM_TYPE", .string(nullable: .blank)),
    .init("NAV_ID", .string(nullable: .blank)),
    .init("NAV_TYPE", .string(nullable: .blank)),
    .init("CITY", .string(nullable: .blank)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("REGION_CODE", .string(nullable: .blank)),
    .init("COUNTRY_CODE", .string(nullable: .blank)),
    .init("COMM_OUTLET_NAME", .string(nullable: .blank)),
    .init("LAT_DECIMAL", .float(nullable: .blank)),
    .init("LONG_DECIMAL", .float(nullable: .blank)),
    .init("FACILITY_ID", .string(nullable: .blank)),
    .init("FACILITY_NAME", .string(nullable: .blank)),
    .init("ALT_FSS_ID", .string(nullable: .blank)),
    .init("ALT_FSS_NAME", .string(nullable: .blank)),
    .init("OPR_HRS", .string(nullable: .blank)),
    .init("COMM_STATUS_CODE", .string(nullable: .blank)),
    .init("COMM_STATUS_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("REMARK", .string(nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    try await parseCSVFile(
      filename: "COM.csv",
      requiredColumns: ["COMM_LOC_ID"]
    ) { row in
      let t = try self.transformer.applyTo(row)

      let outletID = (try t[optional: "COMM_LOC_ID"] ?? "").trimmingCharacters(in: .whitespaces)
      guard !outletID.isEmpty else { return }

      // Parse outlet type
      let outletTypeStr: String? = try t[optional: "COMM_TYPE"]
      let outletType = self.diagnose(
        FSSCommFacility.OutletType.self,
        outletTypeStr,
        field: "outletType",
        id: outletID
      )

      // Parse navaid type from full name (CSV has full name like "VOR/DME" not short code)
      let navaidTypeStr: String? = try t[optional: "NAV_TYPE"]
      let navaidType = self.diagnose(
        Navaid.FacilityType.self,
        navaidTypeStr,
        field: "navaidType",
        id: outletID
      )

      // Parse outlet position from decimal degrees
      let outletPosition: Location? = {
        let lat: Float? = try? t[optional: "LAT_DECIMAL"]
        let lon: Float? = try? t[optional: "LONG_DECIMAL"]
        if let lat, let lon {
          // Convert decimal degrees to arc-seconds
          return Location(
            latitudeArcsec: lat * 3600,
            longitudeArcsec: lon * 3600,
            elevationFtMSL: nil
          )
        }
        return nil
      }()

      // Parse status - CSV uses single-character code; unknown values are diagnosed
      let statusCode: String? = try t[optional: "COMM_STATUS_CODE"]
      var status: FSS.Status?
      if let statusCode, !statusCode.trimmingCharacters(in: .whitespaces).isEmpty {
        do {
          status =
            switch statusCode.trimmingCharacters(in: .whitespaces) {
              case "A": .operationalIFR
              default: throw ParserError.unknownRecordEnumValue(statusCode)
            }
        } catch {
          self.recordFieldError(field: "status", value: statusCode, id: outletID, thrown: error)
        }
      }

      let facility = FSSCommFacility(
        outletIdentifier: outletID,
        outletType: outletType,
        navaidIdentifier: try t[optional: "NAV_ID"],
        navaidType: navaidType,
        navaidCity: nil,  // Not in CSV format
        navaidState: nil,  // Not in CSV format
        navaidName: nil,  // Not in CSV format
        navaidPosition: nil,  // Not in CSV format
        outletCity: try t[optional: "CITY"],
        outletState: try t[optional: "STATE_CODE"],
        regionName: nil,  // Not in CSV format
        regionCode: try t[optional: "REGION_CODE"],
        outletPosition: outletPosition,
        outletCall: try t[optional: "COMM_OUTLET_NAME"],
        frequencies: [],  // Not in CSV format
        FSSIdentifier: try t[optional: "FACILITY_ID"],
        FSSName: try t[optional: "FACILITY_NAME"],
        alternateFSSIdentifier: try t[optional: "ALT_FSS_ID"],
        alternateFSSName: try t[optional: "ALT_FSS_NAME"],
        operationalHours: try t[optional: "OPR_HRS"],
        ownerCode: nil,  // Not in CSV format
        ownerName: nil,  // Not in CSV format
        operatorCode: nil,  // Not in CSV format
        operatorName: nil,  // Not in CSV format
        charts: [],  // Not in CSV format
        timeZone: nil,  // Not in CSV format
        status: status,
        statusDateComponents: try t[optional: "COMM_STATUS_DATE"]
      )

      self.facilities.append(facility)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(FSSCommFacilities: facilities)
  }
}
