import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class CSVWeatherStationParserSpec: AsyncSpec {
  override class func spec() {
    describe("CSVWeatherStationParser") {
      let csvDirectory = Bundle.module.resourceURL!.appendingPathComponent(
        "MockCSVDistribution",
        isDirectory: true
      )

      context("when parsing CSV files") {
        it("parses weather station records") {
          let parser = CSVWeatherStationParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // CSV now has 10 stations matching TXT
          expect(parser.stations.count).to(equal(10))

          // Verify 00U station
          let station00U = parser.stations.values.first { $0.stationId == "00U" }
          expect(station00U).notTo(beNil())
          if let station = station00U {
            expect(station.type).to(equal(WeatherStation.StationType.AWOS3))
            expect(station.stateCode).to(equal("MT"))
            expect(station.city).to(equal("HARDIN"))
            expect(station.isCommissioned).to(beTrue())
            expect(station.position?.latitudeArcsec).notTo(beNil())
            expect(station.position?.longitudeArcsec).notTo(beNil())
            expect(station.position?.elevationFtMSL).to(beCloseTo(3085, within: 1))
            expect(station.surveyMethod).to(equal(SurveyMethod.estimated))
          }
        }

        it("parses different station types") {
          let parser = CSVWeatherStationParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // AWOS-3P station
          let station04V = parser.stations.values.first { $0.stationId == "04V" }
          expect(station04V).notTo(beNil())
          expect(station04V?.type).to(equal(WeatherStation.StationType.AWOS3P))
          expect(station04V?.stateCode).to(equal("CO"))
          expect(station04V?.surveyMethod).to(equal(SurveyMethod.surveyed))

          // AWOS-AV station
          let station06U = parser.stations.values.first { $0.stationId == "06U" }
          expect(station06U).notTo(beNil())
          expect(station06U?.type).to(equal(WeatherStation.StationType.AWOSAV))
          expect(station06U?.stateCode).to(equal("NV"))
        }

        it("parses remarks when present") {
          let parser = CSVWeatherStationParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // 04V has a remark
          let station04V = parser.stations.values.first { $0.stationId == "04V" }
          expect(station04V).notTo(beNil())
          if let station = station04V {
            expect(station.remarks.count).to(beGreaterThan(0))
            expect(station.remarks.first).to(contain("Precipitation"))
          }
        }

        it("correctly parses commission dates") {
          let parser = CSVWeatherStationParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          let station00U = parser.stations.values.first { $0.stationId == "00U" }
          expect(station00U?.commissionDate).notTo(beNil())
        }
      }

      context("when CSV files are missing") {
        it("throws an error for missing files") {
          let parser = CSVWeatherStationParser()
          parser.csvDirectory = URL(fileURLWithPath: "/tmp/nonexistent")

          await expect { try await parser.parse(data: Data()) }.to(throwError())
        }
      }
    }
  }
}
