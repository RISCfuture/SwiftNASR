import Foundation
import StreamingCSV

/// CSV Weather Reporting Location Parser using declarative transformers.
///
/// Parses WXL_BASE.csv and WXL_SVC.csv files to create WeatherReportingLocation records.
actor CSVWeatherReportingLocationParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["WXL_BASE.csv", "WXL_SVC.csv"]

  var locations = [String: WeatherReportingLocation]()

  // WXL_BASE.csv field indices:
  // 0: EFF_DATE, 1: WEA_ID, 2: CITY, 3: STATE_CODE, 4: COUNTRY_CODE,
  // 5: LAT_DEG, 6: LAT_MIN, 7: LAT_SEC, 8: LAT_HEMIS, 9: LAT_DECIMAL,
  // 10: LONG_DEG, 11: LONG_MIN, 12: LONG_SEC, 13: LONG_HEMIS, 14: LONG_DECIMAL,
  // 15: ELEV, 16: SURVEY_METHOD_CODE

  private let baseFieldMapping: [Int] = [
    0,  // 0: EFF_DATE -> skip
    1,  // 1: WEA_ID -> identifier
    2,  // 2: CITY -> city
    3,  // 3: STATE_CODE -> stateCode
    4,  // 4: COUNTRY_CODE -> countryCode
    9,  // 5: LAT_DECIMAL -> latitude
    14,  // 6: LONG_DECIMAL -> longitude
    15,  // 7: ELEV -> elevation
    16  // 8: SURVEY_METHOD_CODE -> elevationAccuracy
  ]

  private let baseTransformer = CSVTransformer([
    .null,  // 0: effective date (skip)
    .string(),  // 1: identifier
    .string(nullable: .blank),  // 2: city
    .string(nullable: .blank),  // 3: state code
    .string(nullable: .blank),  // 4: country code
    .float(nullable: .blank),  // 5: latitude decimal
    .float(nullable: .blank),  // 6: longitude decimal
    .float(nullable: .blank),  // 7: elevation
    .generic({ try parseElevationAccuracy($0) }, nullable: .blank)  // 8: survey method
  ])

  // WXL_SVC.csv field indices:
  // 0: EFF_DATE, 1: WEA_ID, 2: CITY, 3: STATE_CODE, 4: COUNTRY_CODE,
  // 5: WEA_SVC_TYPE_CODE, 6: WEA_AFFECT_AREA

  private let serviceFieldMapping: [Int] = [
    0,  // 0: EFF_DATE -> skip
    1,  // 1: WEA_ID -> identifier
    5,  // 2: WEA_SVC_TYPE_CODE -> service type
    6  // 3: WEA_AFFECT_AREA -> affected areas
  ]

  private let serviceTransformer = CSVTransformer([
    .null,  // 0: effective date (skip)
    .string(),  // 1: identifier
    .generic({ parseWeatherServiceType($0) }, nullable: .blank),  // 2: service type
    .string(nullable: .blank)  // 3: affected areas
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse WXL_BASE.csv for base location data
    try await parseCSVFile(filename: "WXL_BASE.csv", expectedFieldCount: 17) { fields in
      guard fields.count >= 17 else { return }

      // Map CSV fields to transformer indices
      var mappedFields = [String](repeating: "", count: 9)
      for (transformerIndex, csvIndex) in baseFieldMapping.enumerated() {
        if csvIndex >= 0 && csvIndex < fields.count {
          mappedFields[transformerIndex] = fields[csvIndex]
        }
      }

      let transformedValues = try self.baseTransformer.applyTo(
        mappedFields,
        indices: Array(0..<9)
      )

      let identifier = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
      guard !identifier.isEmpty else { return }

      // Build location from decimal lat/lon
      let position: Location? = {
        guard let lat = transformedValues[5] as? Float,
          let lon = transformedValues[6] as? Float
        else {
          return nil
        }
        let elevation = transformedValues[7] as? Float
        return Location(
          latitudeArcsec: lat * 3600,
          longitudeArcsec: lon * 3600,
          elevationFtMSL: elevation
        )
      }()

      let location = WeatherReportingLocation(
        identifier: identifier,
        position: position,
        city: transformedValues[2] as? String,
        stateCode: transformedValues[3] as? String,
        countryCode: transformedValues[4] as? String,
        elevationAccuracy: transformedValues[8] as? WeatherReportingLocation.ElevationAccuracy,
        weatherServices: [],
        collectives: [],
        affectedAreas: []
      )

      self.locations[identifier] = location
    }

    // Parse WXL_SVC.csv for weather services
    try await parseCSVFile(filename: "WXL_SVC.csv", expectedFieldCount: 7) { fields in
      guard fields.count >= 6 else { return }

      // Map CSV fields to transformer indices
      var mappedFields = [String](repeating: "", count: 4)
      for (transformerIndex, csvIndex) in serviceFieldMapping.enumerated() {
        if csvIndex >= 0 && csvIndex < fields.count {
          mappedFields[transformerIndex] = fields[csvIndex]
        }
      }

      let transformedValues = try self.serviceTransformer.applyTo(
        mappedFields,
        indices: Array(0..<4)
      )

      let identifier = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
      guard !identifier.isEmpty else { return }
      guard self.locations[identifier] != nil else { return }

      // Add weather service type if valid
      if let serviceType = transformedValues[2] as? WeatherReportingLocation.WeatherServiceType {
        self.locations[identifier]!.weatherServices.append(serviceType)
      }

      // Handle affected areas if present
      if let affectedAreasStr = transformedValues[3] as? String, !affectedAreasStr.isEmpty {
        // Parse space-separated state codes
        let states = affectedAreasStr.split(separator: " ").map { String($0) }
        if !states.isEmpty,
          let serviceType = transformedValues[2] as? WeatherReportingLocation.WeatherServiceType
        {
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

// MARK: - Private Helpers

private func parseElevationAccuracy(_ str: String) throws
  -> WeatherReportingLocation.ElevationAccuracy?
{
  guard !str.isEmpty else { return nil }
  return WeatherReportingLocation.ElevationAccuracy.for(str)
}

private func parseWeatherServiceType(_ str: String)
  -> WeatherReportingLocation.WeatherServiceType?
{
  guard !str.isEmpty else { return nil }
  return WeatherReportingLocation.WeatherServiceType.for(str)
}
