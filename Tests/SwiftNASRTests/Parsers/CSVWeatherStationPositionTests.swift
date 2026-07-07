import Foundation
import Testing

@testable import SwiftNASR

/// `WeatherStation.position` is optional, so an AWOS record with no coordinates
/// must be kept (with a nil position) rather than dropped. Two real records in
/// the live distribution (e.g. HSS, Hot Springs NC) have blank latitude and
/// longitude.
@Suite
struct CSVWeatherStationPositionTests {
  @Test
  func keepsAStationThatHasNoCoordinatesWithANilPosition() async throws {
    let tempdir = FileManager.default.temporaryDirectory.appendingPathComponent(
      ProcessInfo.processInfo.globallyUniqueString
    )
    try FileManager.default.createDirectory(at: tempdir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempdir) }

    // Build the row from the header so field alignment is independent of the
    // column order. Everything except the named fields is blank — crucially,
    // LAT_DECIMAL and LONG_DECIMAL.
    let columns = [
      "EFF_DATE", "ASOS_AWOS_ID", "ASOS_AWOS_TYPE", "STATE_CODE", "CITY", "COUNTRY_CODE",
      "COMMISSIONED_DATE", "NAVAID_FLAG", "LAT_DEG", "LAT_MIN", "LAT_SEC", "LAT_HEMIS",
      "LAT_DECIMAL", "LONG_DEG", "LONG_MIN", "LONG_SEC", "LONG_HEMIS", "LONG_DECIMAL", "ELEV",
      "SURVEY_METHOD_CODE", "PHONE_NO", "SECOND_PHONE_NO", "SITE_NO", "SITE_TYPE_CODE", "REMARK"
    ]
    let values = [
      "ASOS_AWOS_ID": "HSS", "ASOS_AWOS_TYPE": "ASOS", "STATE_CODE": "NC",
      "CITY": "HOT SPRINGS", "COUNTRY_CODE": "US", "NAVAID_FLAG": "N"
    ]
    let header = columns.joined(separator: ",")
    let row = columns.map { values[$0] ?? "" }.joined(separator: ",")
    try Data("\(header)\r\n\(row)\r\n".utf8).write(to: tempdir.appendingPathComponent("AWOS.csv"))

    let parser = CSVWeatherStationParser()
    let distribution = DirectoryDistribution(location: tempdir, format: .csv)
    try await parser.prepare(distribution: distribution)
    try await parser.parse(data: Data("CSV".utf8))

    let stations = await parser.stations
    let station = stations.values.first { $0.stationId == "HSS" }
    #expect(station != nil)
    #expect(station?.position == nil)
  }
}
