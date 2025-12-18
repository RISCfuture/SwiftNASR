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

  init(values: [Any?]) {
    stationId = (values[1] as! String).trimmingCharacters(in: .whitespaces)
    type = values[2] as! WeatherStation.StationType
  }
}

class FixedWidthWeatherStationParser: FixedWidthParser {
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

  private let basicTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type
    .string(),  //  1 station ID
    .generic { try raw($0, toEnum: WeatherStation.StationType.self) },  //  2 type
    .boolean(),  //  3 commissioning status
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  4 commission date
    .boolean(),  //  5 navaid flag
    .DDMMSS(nullable: .blank),  //  6 latitude
    .DDMMSS(nullable: .blank),  //  7 longitude
    .float(nullable: .blank),  //  8 elevation
    .generic({ try raw($0, toEnum: SurveyMethod.self) }, nullable: .blank),  //  9 survey method
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
  private let remarkTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 station ID
    .generic { try raw($0, toEnum: WeatherStation.StationType.self) },  // 2 type
    .string(nullable: .blank)  // 3 remark text
  ])

  func parseValues(_ values: [String], for identifier: WeatherStationRecordIdentifier) throws {
    switch identifier {
      case .basicInfo: try parseBasicRecord(values)
      case .remark: try parseRemark(values)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(weatherStations: Array(stations.values))
  }

  private func parseBasicRecord(_ values: [String]) throws {
    let transformedValues = try basicTransformer.applyTo(values)

    let position: Location?
    if let lat = transformedValues[6] as? Float, let lon = transformedValues[7] as? Float {
      position = Location(
        latitudeArcsec: lat,
        longitudeArcsec: lon,
        elevationFtMSL: transformedValues[8] as? Float
      )
    } else {
      position = nil
    }

    let station = WeatherStation(
      stationId: transformedValues[1] as! String,
      type: transformedValues[2] as! WeatherStation.StationType,
      stateCode: transformedValues[16] as? String,
      city: transformedValues[15] as? String,
      country: nil,  // Not in TXT format
      isCommissioned: transformedValues[3] as! Bool,
      commissionDate: transformedValues[4] as? DateComponents,
      isNavaidAssociated: transformedValues[5] as? Bool,
      position: position,
      surveyMethod: transformedValues[9] as? SurveyMethod,
      frequencyKHz: transformedValues[10] as? UInt,
      secondaryFrequencyKHz: transformedValues[11] as? UInt,
      phoneNumber: transformedValues[12] as? String,
      secondaryPhoneNumber: transformedValues[13] as? String,
      airportSiteNumber: transformedValues[14] as? String
    )

    stations[WeatherStationKey(station: station)] = station
  }

  private func parseRemark(_ values: [String]) throws {
    let transformedValues = try remarkTransformer.applyTo(values)

    guard let remarkText = transformedValues[3] as? String, !remarkText.isEmpty else {
      return
    }

    try updateStation(transformedValues) { station in
      station.remarks.append(remarkText)
    }
  }

  private func updateStation(_ values: [Any?], process: (inout WeatherStation) throws -> Void)
    throws
  {
    let key = WeatherStationKey(values: values)
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
