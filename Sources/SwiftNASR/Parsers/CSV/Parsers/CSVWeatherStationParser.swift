import Foundation
import StreamingCSV
import ZIPFoundation

/// CSV Weather Station Parser for parsing AWOS.csv
class CSVWeatherStationParser: CSVParser {
  var csvDirectory = URL(fileURLWithPath: "/")
  var stations = [WeatherStationKey: WeatherStation]()

  // CSV field mapping for AWOS.csv (0-based indices)
  // Headers: EFF_DATE,ASOS_AWOS_ID,ASOS_AWOS_TYPE,STATE_CODE,CITY,COUNTRY_CODE,COMMISSIONED_DATE,NAVAID_FLAG,
  //          LAT_DEG,LAT_MIN,LAT_SEC,LAT_HEMIS,LAT_DECIMAL,LONG_DEG,LONG_MIN,LONG_SEC,LONG_HEMIS,LONG_DECIMAL,
  //          ELEV,SURVEY_METHOD_CODE,PHONE_NO,SECOND_PHONE_NO,SITE_NO,SITE_TYPE_CODE,REMARK
  private let csvFieldMapping: [Int] = [
    0,  //  0: EFF_DATE
    1,  //  1: ASOS_AWOS_ID
    2,  //  2: ASOS_AWOS_TYPE
    3,  //  3: STATE_CODE
    4,  //  4: CITY
    5,  //  5: COUNTRY_CODE
    6,  //  6: COMMISSIONED_DATE
    7,  //  7: NAVAID_FLAG
    12,  //  8: LAT_DECIMAL
    17,  //  9: LONG_DECIMAL
    18,  // 10: ELEV
    19,  // 11: SURVEY_METHOD_CODE
    20,  // 12: PHONE_NO
    21,  // 13: SECOND_PHONE_NO
    22,  // 14: SITE_NO
    24  // 15: REMARK
  ]

  private let basicTransformer = CSVTransformer([
    .null,  //  0: effective date
    .string(),  //  1: station ID
    .generic { try raw($0, toEnum: WeatherStation.StationType.self) },  //  2: type
    .string(nullable: .blank),  //  3: state code
    .string(nullable: .blank),  //  4: city
    .string(nullable: .blank),  //  5: country code
    .dateComponents(format: .yearMonthDaySlash, nullable: .blank),  //  6: commission date
    .boolean(),  //  7: navaid flag
    .float(nullable: .blank),  //  8: lat decimal
    .float(nullable: .blank),  //  9: lon decimal
    .float(nullable: .blank),  // 10: elevation
    .generic({ try raw($0, toEnum: SurveyMethod.self) }, nullable: .blank),  // 11: survey method
    .string(nullable: .blank),  // 12: phone number
    .string(nullable: .blank),  // 13: secondary phone number
    .string(nullable: .blank),  // 14: site number
    .string(nullable: .blank)  // 15: remark
  ])

  func prepare(distribution: Distribution) throws {
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
    try await parseCSVFile(filename: "AWOS.csv", expectedFieldCount: 25) { fields in
      guard fields.count >= 19 else {
        throw ParserError.truncatedRecord(
          recordType: "AWOS",
          expectedMinLength: 19,
          actualLength: fields.count
        )
      }

      var mappedFields = [String](repeating: "", count: 16)
      for (transformerIndex, csvIndex) in self.csvFieldMapping.enumerated()
      where csvIndex < fields.count {
        mappedFields[transformerIndex] = fields[csvIndex]
      }

      let transformedValues = try self.basicTransformer.applyTo(
        mappedFields,
        indices: Array(0..<16)
      )

      // Parse position from decimal degrees - convert to arc-seconds for Location
      let latDecimal = transformedValues[8] as? Float
      let lonDecimal = transformedValues[9] as? Float
      let elevation = transformedValues[10] as? Float
      let stationID = transformedValues[1] as! String

      guard
        let position = try self.makeLocation(
          latitude: latDecimal,
          longitude: lonDecimal,
          elevation: elevation,
          context: "weather station \(stationID)"
        )
      else {
        throw ParserError.missingRequiredField(field: "position", recordType: "AWOS")
      }

      // CSV has a single remark field, but we need to check commission status
      // Since the COMMISSIONED_DATE can be empty or a date
      let commissionDateStr = fields[6]
      let isCommissioned = !commissionDateStr.isEmpty

      var station = WeatherStation(
        stationId: stationID,
        type: transformedValues[2] as! WeatherStation.StationType,
        stateCode: transformedValues[3] as? String,
        city: transformedValues[4] as? String,
        country: transformedValues[5] as? String,
        isCommissioned: isCommissioned,
        commissionDate: transformedValues[6] as? DateComponents,
        isNavaidAssociated: transformedValues[7] as? Bool,
        position: position,
        surveyMethod: transformedValues[11] as? SurveyMethod,
        frequencyKHz: nil,  // Not directly in CSV (would need to parse from another source)
        secondaryFrequencyKHz: nil,
        phoneNumber: transformedValues[12] as? String,
        secondaryPhoneNumber: transformedValues[13] as? String,
        airportSiteNumber: transformedValues[14] as? String
      )

      // Add remark if present
      if let remark = transformedValues[15] as? String, !remark.isEmpty {
        station.remarks.append(remark)
      }

      let key = WeatherStationKey(station: station)
      self.stations[key] = station
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(weatherStations: Array(stations.values))
  }

  /// Creates a Location from optional lat/lon (decimal degrees), throwing if only one is present.
  /// Converts decimal degrees to arc-seconds for Location storage.
  private func makeLocation(
    latitude: Float?,
    longitude: Float?,
    elevation: Float?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        // Convert decimal degrees to arc-seconds (multiply by 3600)
        return Location(
          latitudeArcsec: lat * 3600,
          longitudeArcsec: lon * 3600,
          elevationFtMSL: elevation
        )
      case (.none, .none):
        return nil
      default:
        throw ParserError.invalidLocation(
          latitude: latitude,
          longitude: longitude,
          context: context
        )
    }
  }
}
