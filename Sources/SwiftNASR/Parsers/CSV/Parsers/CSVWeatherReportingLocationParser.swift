import Foundation
import StreamingCSV

/// CSV Weather Reporting Location Parser using declarative transformers.
///
/// Parses WXL_BASE.csv and WXL_SVC.csv files to create WeatherReportingLocation records.
actor CSVWeatherReportingLocationParser: CSVParser, DiagnosingParser {
  static let type = RecordType.weatherReportingLocations
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["WXL_BASE.csv", "WXL_SVC.csv"]

  var pendingDiagnostics = [RecordParseError]()
  var locations = [String: WeatherReportingLocation]()

  private let baseTransformer = CSVTransformer([
    .init("WEA_ID", .string()),
    .init("CITY", .string(nullable: .blank)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("COUNTRY_CODE", .string(nullable: .blank)),
    .init("LAT_DECIMAL", .float(nullable: .blank)),
    .init("LONG_DECIMAL", .float(nullable: .blank)),
    .init("ELEV", .float(nullable: .blank)),
    .init("SURVEY_METHOD_CODE", .string(nullable: .blank))
  ])

  private let serviceTransformer = CSVTransformer([
    .init("WEA_ID", .string()),
    .init("WEA_SVC_TYPE_CODE", .string(nullable: .blank)),
    .init("WEA_AFFECT_AREA", .string(nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse WXL_BASE.csv for base location data
    try await parseCSVFile(
      filename: "WXL_BASE.csv",
      requiredColumns: ["WEA_ID"]
    ) { row in
      let t = try self.baseTransformer.applyTo(row)

      let identifierRaw: String = try t["WEA_ID"]
      let identifier = identifierRaw.trimmingCharacters(in: .whitespaces)
      guard !identifier.isEmpty else { return }

      // Build location from decimal lat/lon
      let position: Location? = {
        guard let lat: Float = try? t[optional: "LAT_DECIMAL"],
          let lon: Float = try? t[optional: "LONG_DECIMAL"]
        else {
          return nil
        }
        let elevation: Float? = try? t[optional: "ELEV"]
        return Location(
          latitudeArcsec: lat * 3600,
          longitudeArcsec: lon * 3600,
          elevationFtMSL: elevation
        )
      }()

      let location = WeatherReportingLocation(
        identifier: identifier,
        position: position,
        city: try t[optional: "CITY"],
        stateCode: try t[optional: "STATE_CODE"],
        countryCode: try t[optional: "COUNTRY_CODE"],
        elevationAccuracy: diagnose(
          WeatherReportingLocation.ElevationAccuracy.self,
          try t[optional: "SURVEY_METHOD_CODE"],
          field: "elevationAccuracy",
          id: identifier
        ),
        weatherServices: [],
        collectives: [],
        affectedAreas: []
      )

      self.locations[identifier] = location
    }

    // Parse WXL_SVC.csv for weather services
    try await parseCSVFile(
      filename: "WXL_SVC.csv",
      requiredColumns: ["WEA_ID"]
    ) { row in
      let t = try self.serviceTransformer.applyTo(row)

      let identifierRaw: String = try t["WEA_ID"]
      let identifier = identifierRaw.trimmingCharacters(in: .whitespaces)
      guard !identifier.isEmpty else { return }
      guard self.locations[identifier] != nil else { return }

      // Add weather service type if valid
      let serviceType = self.diagnose(
        WeatherReportingLocation.WeatherServiceType.self,
        try t[optional: "WEA_SVC_TYPE_CODE"],
        field: "weatherServices",
        id: identifier
      )
      if let serviceType {
        self.locations[identifier]!.weatherServices.append(serviceType)
      }

      // Handle affected areas if present
      if let affectedAreasStr: String = try t[optional: "WEA_AFFECT_AREA"],
        !affectedAreasStr.isEmpty
      {
        // Parse space-separated state codes
        let states = affectedAreasStr.split(separator: " ").map { String($0) }
        if !states.isEmpty, let serviceType {
          let affectedArea = WeatherReportingLocation.AffectedArea(
            serviceType: serviceType,
            states: states
          )
          self.locations[identifier]!.affectedAreas.append(affectedArea)
        }
      }
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(weatherReportingLocations: Array(locations.values))
  }
}
