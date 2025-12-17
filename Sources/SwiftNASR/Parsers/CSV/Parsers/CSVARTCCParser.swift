import Foundation
import StreamingCSV
import ZIPFoundation

/// CSV ARTCC Parser using declarative transformers like FixedWidthARTCCParser
class CSVARTCCParser: CSVParser {
  var csvDirectory = URL(fileURLWithPath: "/")
  var ARTCCs = [ARTCCKey: ARTCC]()

  // Matching FixedWidthARTCCParser transformer field types
  private let generalTransformer = CSVTransformer([
    .null,  //  0 effective date
    .string(),  //  1 identifier (FACILITY_ID)
    .string(),  //  2 name (FACILITY_NAME)
    .string(),  //  3 location name (CITY)
    .string(nullable: .blank),  //  4 cross reference
    .string(),  //  5 facility type (parsed separately)
    .null,  //  6 effective date (duplicate)
    .null,  //  7 state name
    .string(nullable: .blank),  //  8 state PO code
    .null,  //  9 latitude - formatted (not in CSV)
    .null,  // 10 latitude - decimal (not in CSV)
    .null,  // 11 longitude - formatted (not in CSV)
    .null,  // 12 longitude - decimal (not in CSV)
    .string(nullable: .blank),  // 13 ICAO ID
    .null  // 14 blank
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
    // Parse ATC_BASE.csv
    try await parseCSVFile(filename: "ATC_BASE.csv", expectedFieldCount: 30) { fields in
      guard fields.count >= 10 else { return }

      // Map CSV fields to transformer indices
      let indices = [
        0,  // EFF_DATE -> 0
        5,  // FACILITY_ID -> 1
        9,  // FACILITY_NAME -> 2
        6,  // CITY -> 3
        -1,  // No cross reference in CSV
        3,  // FACILITY_TYPE -> 5
        0,  // EFF_DATE again -> 6
        -1,  // STATE_NAME not in CSV
        4,  // STATE_CODE -> 8
        -1,  // No lat formatted
        -1,  // No lat decimal
        -1,  // No lon formatted
        -1,  // No lon decimal
        8,  // ICAO_ID -> 13
        -1  // blank
      ]

      let transformedValues = try self.generalTransformer.applyTo(fields, indices: indices)

      // Use custom parser for facility type instead of the transformed value
      let facilityType = self.parseFacilityType(fields[3])

      let center = ARTCC(
        code: transformedValues[1] as! String,
        ICAOID: transformedValues[13] as? String,
        type: facilityType,
        name: transformedValues[2] as! String,
        alternateName: nil,
        locationName: transformedValues[3] as! String,
        stateCode: transformedValues[8] as? String,
        location: nil  // Would need to parse lat/lon if available
      )

      let key = ARTCCKey(center: center)
      self.ARTCCs[key] = center
    }

    // Parse ATC_RMK.csv for remarks
    try await parseCSVFile(filename: "ATC_RMK.csv", expectedFieldCount: 13) { fields in
      guard fields.count >= 13 else { return }

      // Only process remarks for ARTCC facility types
      let facilityType = self.parseFacilityType(fields[3])
      guard
        facilityType == .ARTCC || facilityType == .CERAP || facilityType == .RCAG
          || facilityType == .SECRA || facilityType == .ARSR
      else { return }

      let facilityID = fields[5].trimmingCharacters(in: .whitespaces)
      let city = fields[6].trimmingCharacters(in: .whitespaces)
      let remark = fields[12].trimmingCharacters(in: .whitespaces)

      guard !facilityID.isEmpty, !remark.isEmpty else { return }

      let key = ARTCCKey(values: [nil, facilityID, city, facilityType])
      if var center = self.ARTCCs[key] {
        center.remarks.append(.general(remark))
        self.ARTCCs[key] = center
      }
    }

    // Parse ATC_SVC.csv for services
    try await parseCSVFile(filename: "ATC_SVC.csv", expectedFieldCount: 9) { fields in
      guard fields.count >= 9 else { return }

      // Only process services for ARTCC facility types
      let facilityType = self.parseFacilityType(fields[3])
      guard
        facilityType == .ARTCC || facilityType == .CERAP || facilityType == .RCAG
          || facilityType == .SECRA || facilityType == .ARSR
      else { return }

      let facilityID = fields[5].trimmingCharacters(in: .whitespaces)
      let city = fields[6].trimmingCharacters(in: .whitespaces)
      let service = fields[8].trimmingCharacters(in: .whitespaces)

      guard !facilityID.isEmpty, !service.isEmpty else { return }

      let key = ARTCCKey(values: [nil, facilityID, city, facilityType])
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

  private func parseFacilityType(_ type: String) -> ARTCC.FacilityType {
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
      // Map TRACON and ATCT facilities to CERAP (Center Radar Approach Control)
      // since they provide similar approach control services
      case "TRACON", "ATCT", "NON-ATCT", "ATCT-TRACON", "ATCT-A/C",
        "ATCT-RAPCON", "ATCT-RATCF":
        return .CERAP
      default:
        // Default to ARTCC for unknown types
        return .ARTCC
    }
  }
}
