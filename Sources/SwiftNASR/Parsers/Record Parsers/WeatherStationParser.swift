import Foundation

enum WeatherStationRecordIdentifier: String {
  case basicInfo = "AWOS1"
  case remark = "AWOS2"
}

struct WeatherStationKey: Hashable {
  let stationId: String
  let type: WeatherStation.StationType

  init(station: WeatherStation) {
    stationId = station.stationId
    type = station.type
  }

  init(values: FixedWidthTransformedRow) throws {
    stationId = try (values[1] as String).trimmingCharacters(in: .whitespaces)
    type = try values[2]
  }
}

actor FixedWidthWeatherStationParser: FixedWidthParser {
  typealias RecordIdentifier = WeatherStationRecordIdentifier

  static let type: RecordType = .weatherReportingStations
  static let layoutFormatOrder: [WeatherStationRecordIdentifier] = [
    .basicInfo, .remark
  ]

  var recordTypeRange: Range<UInt> { 0..<5 }
  var formats = [NASRTable]()
  var stations = [WeatherStationKey: WeatherStation]()

  // AWOS1 - Base data
  // Based on layout data:
  // L  AN  0005 00001  N/A     RECORD TYPE INDICATOR (AWOS1)
  // L  AN  0004 00006  N/A     WX SENSOR IDENT
  // L  AN  0010 00010  N/A     WX SENSOR TYPE
  // L  AN  0001 00020  N/A     COMMISSIONING STATUS (Y/N)
  // L  AN  0010 00021  N/A     COMMISSIONING/DECOMMISSIONING DATE (MM/DD/YYYY)
  // L  AN  0001 00031  N/A     NAVAID FLAG (Y/N)
  // L  AN  0014 00032  N/A     STATION LATITUDE (DD-MM-SS.SSSSH)
  // L  AN  0015 00046  N/A     STATION LONGITUDE (DDD-MM-SS.SSSSH)
  // L  AN  0007 00061  N/A     ELEVATION
  // L  AN  0001 00068  N/A     SURVEY METHOD CODE (E/S)
  // L  AN  0007 00069  N/A     STATION FREQUENCY
  // L  AN  0007 00076  N/A     SECOND STATION FREQUENCY
  // L  AN  0014 00083  N/A     STATION TELEPHONE NUMBER
  // L  AN  0014 00097  N/A     SECOND STATION TELEPHONE NUMBER
  // L  AN  0011 00111  A0      LANDING FACILITY SITE NUMBER
  // L  AN  0040 00122  N/A     STATION CITY
  // L  AN  0002 00162  N/A     STATION STATE POST OFFICE CODE
  // L  AN  0010 00164  N/A     INFORMATION EFFECTIVE DATE
  //       0082 00174  N/A     BLANKS: FILLER

  private let basicTransformer = ByteTransformer([
    .recordType,  //  0 record type
    .string(),  //  1 station ID
    .recordEnum(WeatherStation.StationType.self),  //  2 type
    .boolean(),  //  3 commissioning status
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  4 commission date
    .boolean(),  //  5 navaid flag
    .DDMMSS(nullable: .blank),  //  6 latitude
    .DDMMSS(nullable: .blank),  //  7 longitude
    .float(nullable: .blank),  //  8 elevation
    .recordEnum(SurveyMethod.self, nullable: .blank),  //  9 survey method
    .frequency(nullable: .blank),  // 10 primary frequency
    .frequency(nullable: .blank),  // 11 secondary frequency
    .string(nullable: .blank),  // 12 phone number
    .string(nullable: .blank),  // 13 secondary phone number
    .string(nullable: .blank),  // 14 airport site number
    .string(nullable: .blank),  // 15 city
    .string(nullable: .blank),  // 16 state code
    .null,  // 17 effective date
    .null  // 18 blanks
  ])

  // AWOS2 - Remarks
  private let remarkTransformer = ByteTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 station ID
    .recordEnum(WeatherStation.StationType.self),  // 2 type
    .string(nullable: .blank)  // 3 remark text
  ])

  func parseValues(_ values: [ArraySlice<UInt8>], for identifier: WeatherStationRecordIdentifier)
    throws
  {
    switch identifier {
      case .basicInfo: try parseBasicRecord(values)
      case .remark: try parseRemark(values)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(weatherStations: Array(stations.values))
  }

  private func parseBasicRecord(_ values: [ArraySlice<UInt8>]) throws {
    let t = try basicTransformer.applyTo(values)

    let position: Location?
    if let lat: Float = try t[optional: 6], let lon: Float = try t[optional: 7] {
      position = Location(
        latitudeArcsec: lat,
        longitudeArcsec: lon,
        elevationFtMSL: try t[optional: 8]
      )
    } else {
      position = nil
    }

    let station = WeatherStation(
      stationId: try t[1],
      type: try t[2],
      stateCode: try t[optional: 16],
      city: try t[optional: 15],
      country: nil,  // Not in TXT format
      isCommissioned: try t[3],
      commissionDateComponents: try t[optional: 4],
      isNavaidAssociated: try t[optional: 5],
      position: position,
      surveyMethod: try t[optional: 9],
      frequencyKHz: try t[optional: 10],
      secondaryFrequencyKHz: try t[optional: 11],
      phoneNumber: try t[optional: 12],
      secondaryPhoneNumber: try t[optional: 13],
      airportSiteNumber: try t[optional: 14]
    )

    stations[WeatherStationKey(station: station)] = station
  }

  private func parseRemark(_ values: [ArraySlice<UInt8>]) throws {
    let t = try remarkTransformer.applyTo(values)

    guard let remarkText: String = try t[optional: 3], !remarkText.isEmpty else {
      return
    }

    try updateStation(t) { station in
      station.remarks.append(remarkText)
    }
  }

  private func updateStation(
    _ values: FixedWidthTransformedRow,
    process: (inout WeatherStation) throws -> Void
  )
    throws
  {
    let key = try WeatherStationKey(values: values)
    guard var station = stations[key] else {
      throw ParserError.unknownParentRecord(
        parentType: "WeatherStation",
        parentID: key.stationId,
        childType: "remark"
      )
    }
    try process(&station)
    stations[key] = station
  }
}
