import Foundation

/// Parser for WXL (Weather Reporting Locations) files.
///
/// These files contain weather reporting location information.
/// Records are 135 characters fixed-width with multiple record types:
/// - Base records: Start with location identifier
/// - Collective records: Start with '*' followed by FT or SD service type
/// - Affected areas records: Start with '*' followed by other service types
///
/// Note: This parser uses hardcoded field positions rather than layout file formats
/// because the record type detection logic is complex (based on first character and
/// content of subsequent fields).
actor FixedWidthWeatherReportingLocationParser: LayoutDataParser {
  static let type = RecordType.weatherReportingLocations

  // Base record field positions (0-indexed start, length)
  private static let baseFields: [(Int, Int)] = [
    (0, 5),  // identifier
    (5, 8),  // latitude
    (13, 9),  // longitude
    (22, 40),  // city
    (62, 2),  // state code
    (64, 3),  // country code
    (67, 5),  // elevation
    (72, 1),  // elevation accuracy
    (73, 60)  // weather services
  ]

  var formats = [NASRTable]()
  var locations = [String: WeatherReportingLocation]()
  var currentLocationId: String?

  private let baseTransformer = FixedWidthTransformer([
    .string(),  // 0 identifier (5)
    .string(nullable: .blank),  // 1 latitude DDMMSSTC (8)
    .string(nullable: .blank),  // 2 longitude DDDMMSSTC (9)
    .string(nullable: .blank),  // 3 city (40)
    .string(nullable: .blank),  // 4 state code (2)
    .string(nullable: .blank),  // 5 country code (3)
    .integer(nullable: .blank),  // 6 elevation (5)
    .string(nullable: .blank),  // 7 elevation accuracy (1)
    .string(nullable: .blank)  // 8 weather services (60)
  ])

  func parse(data: Data) throws {
    guard data.count >= 7 else {
      throw ParserError.truncatedRecord(
        recordType: "WXL",
        expectedMinLength: 7,
        actualLength: data.count
      )
    }

    // Check if this is a continuation record
    if data[0] == 0x2A {  // '*' character
      try parseContinuationRecord(data)
    } else {
      try parseBaseRecord(data)
    }
  }

  private func parseBaseRecord(_ data: Data) throws {
    // Extract field values using hardcoded positions
    let values = Self.baseFields.map { start, length -> String in
      guard start < data.count else { return "" }
      let range = start..<min(start + length, data.count)
      return String(data: data[range], encoding: .isoLatin1) ?? ""
    }

    let t = try baseTransformer.applyTo(values)

    let identifier: String = try t[0]
    let trimmedId = identifier.trimmingCharacters(in: .whitespaces)
    guard !trimmedId.isEmpty else {
      throw ParserError.missingRequiredField(field: "identifier", recordType: "WXL")
    }

    let latStr: String? = try t[optional: 1]
    let lonStr: String? = try t[optional: 2]

    let latitude = parseLatitude(latStr ?? "")
    let longitude = parseLongitude(lonStr ?? "")
    let city: String? = try t[optional: 3]
    let stateCode: String? = try t[optional: 4]
    let countryCode: String? = try t[optional: 5]
    let elevation: Int? = try t[optional: 6]
    let elevAccuracyStr: String? = try t[optional: 7]
    let servicesStr: String? = try t[optional: 8]

    let elevationAccuracy = WeatherReportingLocation.ElevationAccuracy.for(elevAccuracyStr ?? "")
    let weatherServices = parseWeatherServices(servicesStr ?? "")

    let position = try makeLocation(
      latitude: latitude,
      longitude: longitude,
      elevation: elevation.map { Float($0) },
      context: "weather reporting location \(trimmedId)"
    )

    let location = WeatherReportingLocation(
      identifier: trimmedId,
      position: position,
      city: city,
      stateCode: stateCode,
      countryCode: countryCode,
      elevationAccuracy: elevationAccuracy,
      weatherServices: weatherServices,
      collectives: [],
      affectedAreas: []
    )

    locations[trimmedId] = location
    currentLocationId = trimmedId
  }

  private func parseContinuationRecord(_ data: Data) throws {
    guard let currentId = currentLocationId, locations[currentId] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "WeatherReportingLocation",
        parentID: currentLocationId ?? "unknown",
        childType: "continuation"
      )
    }

    // Get service type (positions 1-5)
    let serviceTypeRange = 1..<min(6, data.count)
    let serviceTypeStr =
      String(data: data[serviceTypeRange], encoding: .isoLatin1)?.trimmingCharacters(
        in: .whitespaces
      ) ?? ""

    // Collective records: FT or SD with single digit at position 6
    if serviceTypeStr == "FT" || serviceTypeStr == "SD" {
      if data.count > 6 {
        let collectiveNumStr =
          String(data: data[6..<7], encoding: .isoLatin1)?.trimmingCharacters(in: .whitespaces)
          ?? ""
        if let collectiveNum = UInt(collectiveNumStr) {
          let serviceType = WeatherReportingLocation.WeatherServiceType.for(serviceTypeStr)
          let collective = WeatherReportingLocation.Collective(
            serviceType: serviceType,
            number: collectiveNum
          )
          locations[currentId]?.collectives.append(collective)
        }
      }
    } else {
      // Affected areas record
      if data.count > 6 {
        let statesRange = 6..<min(120, data.count)
        let statesStr =
          String(data: data[statesRange], encoding: .isoLatin1)?.trimmingCharacters(
            in: .whitespaces
          ) ?? ""
        let states = statesStr.split(separator: " ").map { String($0) }

        if !states.isEmpty {
          let serviceType = WeatherReportingLocation.WeatherServiceType.for(serviceTypeStr)
          let affectedArea = WeatherReportingLocation.AffectedArea(
            serviceType: serviceType,
            states: states
          )
          locations[currentId]?.affectedAreas.append(affectedArea)
        }
      }
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(weatherReportingLocations: Array(locations.values))
  }

  // MARK: - Private Helpers

  /// Creates a Location from optional lat/lon, throwing if only one is present.
  private func makeLocation(
    latitude: Double?,
    longitude: Double?,
    elevation: Float?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        return Location(latitudeDeg: lat, longitudeDeg: lon, elevationFtMSL: elevation)
      case (.none, .none):
        return nil
      default:
        throw ParserError.invalidLocation(
          latitude: latitude.map { Float($0) },
          longitude: longitude.map { Float($0) },
          context: context
        )
    }
  }

  /// Parse latitude string (DDMMSSTC format, e.g., "3231001N")
  private func parseLatitude(_ str: String) -> Double? {
    guard str.count >= 8 else { return nil }

    let degStr = String(str.prefix(2))
    let minStr = String(str.dropFirst(2).prefix(2))
    let secStr = String(str.dropFirst(4).prefix(2))
    let tenthsStr = String(str.dropFirst(6).prefix(1))
    let direction = String(str.suffix(1))

    guard let degrees = Double(degStr),
      let minutes = Double(minStr),
      let seconds = Double(secStr),
      let tenths = Double(tenthsStr)
    else { return nil }

    let totalSeconds = seconds + (tenths / 10.0)
    var lat = degrees + (minutes / 60.0) + (totalSeconds / 3600.0)

    if direction == "S" { lat = -lat }
    return lat
  }

  /// Parse longitude string (DDDMMSSTC format, e.g., "08723071W")
  private func parseLongitude(_ str: String) -> Double? {
    guard str.count >= 9 else { return nil }

    let degStr = String(str.prefix(3))
    let minStr = String(str.dropFirst(3).prefix(2))
    let secStr = String(str.dropFirst(5).prefix(2))
    let tenthsStr = String(str.dropFirst(7).prefix(1))
    let direction = String(str.suffix(1))

    guard let degrees = Double(degStr),
      let minutes = Double(minStr),
      let seconds = Double(secStr),
      let tenths = Double(tenthsStr)
    else { return nil }

    let totalSeconds = seconds + (tenths / 10.0)
    var lon = degrees + (minutes / 60.0) + (totalSeconds / 3600.0)

    if direction == "W" { lon = -lon }
    return lon
  }

  /// Parse weather services string (space-separated service codes)
  private func parseWeatherServices(_ str: String) -> [WeatherReportingLocation.WeatherServiceType]
  {
    guard !str.isEmpty else { return [] }

    var services = [WeatherReportingLocation.WeatherServiceType]()
    var remaining = str

    // Known service codes in order of length (longest first to match correctly)
    let knownCodes = [
      "NOTAM", "METAR", "SPECI", "TWEB", "SYNS",
      "AWW", "CWA", "MIS", "TAF", "WST",
      "AC", "FA", "FD", "FT", "FX", "SA", "SD", "UA", "WA", "WH", "WO", "WS", "WW"
    ]

    while !remaining.isEmpty {
      remaining = remaining.trimmingCharacters(in: .whitespaces)
      if remaining.isEmpty { break }

      var matched = false
      for code in knownCodes where remaining.hasPrefix(code) {
        if let serviceType = WeatherReportingLocation.WeatherServiceType.for(code) {
          services.append(serviceType)
        }
        remaining = String(remaining.dropFirst(code.count))
        matched = true
        break
      }

      // If no match, skip one character (shouldn't happen with valid data)
      if !matched {
        remaining = String(remaining.dropFirst())
      }
    }

    return services
  }
}
