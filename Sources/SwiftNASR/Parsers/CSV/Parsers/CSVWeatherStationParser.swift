import Foundation
import StreamingCSV

/// CSV Weather Station Parser for parsing AWOS.csv
actor CSVWeatherStationParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["AWOS.csv"]

  var stations = [WeatherStationKey: WeatherStation]()

  private let basicTransformer = CSVTransformer([
    .init("ASOS_AWOS_ID", .string()),
    .init("ASOS_AWOS_TYPE", .recordEnum(WeatherStation.StationType.self)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("CITY", .string(nullable: .blank)),
    .init("COUNTRY_CODE", .string(nullable: .blank)),
    .init("COMMISSIONED_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("NAVAID_FLAG", .boolean()),
    .init("LAT_DECIMAL", .float(nullable: .blank)),
    .init("LONG_DECIMAL", .float(nullable: .blank)),
    .init("ELEV", .float(nullable: .blank)),
    .init("SURVEY_METHOD_CODE", .recordEnum(SurveyMethod.self, nullable: .blank)),
    .init("PHONE_NO", .string(nullable: .blank)),
    .init("SECOND_PHONE_NO", .string(nullable: .blank)),
    .init("SITE_NO", .string(nullable: .blank)),
    .init("REMARK", .string(nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    try await parseCSVFile(
      filename: "AWOS.csv",
      requiredColumns: ["ASOS_AWOS_ID", "ASOS_AWOS_TYPE", "LAT_DECIMAL", "LONG_DECIMAL"]
    ) { row in
      let t = try self.basicTransformer.applyTo(row)

      // Parse position from decimal degrees - convert to arc-seconds for Location
      let latDecimal: Float? = try t[optional: "LAT_DECIMAL"]
      let lonDecimal: Float? = try t[optional: "LONG_DECIMAL"]
      let elevation: Float? = try t[optional: "ELEV"]
      let stationID: String = try t["ASOS_AWOS_ID"]

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
      let commissionDate: DateComponents? = try t[optional: "COMMISSIONED_DATE"]
      let isCommissioned = commissionDate != nil

      var station = WeatherStation(
        stationId: stationID,
        type: try t["ASOS_AWOS_TYPE"],
        stateCode: try t[optional: "STATE_CODE"],
        city: try t[optional: "CITY"],
        country: try t[optional: "COUNTRY_CODE"],
        isCommissioned: isCommissioned,
        commissionDateComponents: commissionDate,
        isNavaidAssociated: try t[optional: "NAVAID_FLAG"],
        position: position,
        surveyMethod: try t[optional: "SURVEY_METHOD_CODE"],
        frequencyKHz: nil,  // Not directly in CSV (would need to parse from another source)
        secondaryFrequencyKHz: nil,
        phoneNumber: try t[optional: "PHONE_NO"],
        secondaryPhoneNumber: try t[optional: "SECOND_PHONE_NO"],
        airportSiteNumber: try t[optional: "SITE_NO"]
      )

      // Add remark if present
      if let remark: String = try t[optional: "REMARK"], !remark.isEmpty {
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
