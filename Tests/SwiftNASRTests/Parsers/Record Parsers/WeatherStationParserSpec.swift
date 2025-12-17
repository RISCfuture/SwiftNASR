import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class WeatherStationParserSpec: AsyncSpec {
  override class func spec() {
    describe("parse") {
      let distURL = Bundle.module.resourceURL!.appendingPathComponent(
        "MockDistribution",
        isDirectory: true
      )
      let nasr = NASR.fromLocalDirectory(distURL)

      beforeEach {
        try await nasr.load()
      }

      it("parses weather stations") {
        try await nasr.parse(RecordType.weatherReportingStations) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let stations = await nasr.data.weatherStations else {
          fail()
          return
        }
        // AWOS.txt has 10 weather stations
        expect(stations.count).to(equal(10))

        // Verify first station - 00U AWOS-3
        guard let station00U = stations.first(where: { $0.stationId == "00U" }) else {
          fail("00U station not found")
          return
        }
        expect(station00U.type).to(equal(WeatherStation.StationType.AWOS3))
        expect(station00U.stateCode).to(equal("MT"))
        expect(station00U.city).to(equal("HARDIN"))
        expect(station00U.isCommissioned).to(beTrue())
        // Position stored as arc-seconds: 45.7453194 * 3600 = 164683.15
        expect(station00U.position?.latitude).to(beCloseTo(164683.15, within: 1.0))
        // -107.6598139 * 3600 = -387575.33
        expect(station00U.position?.longitude).to(beCloseTo(-387575.33, within: 1.0))
        expect(station00U.position?.elevation).to(beCloseTo(3085.0, within: 0.1))
        expect(station00U.frequency).to(equal(118325))

        // Verify station with AWOS-3P type
        guard let station04V = stations.first(where: { $0.stationId == "04V" }) else {
          fail("04V station not found")
          return
        }
        expect(station04V.type).to(equal(WeatherStation.StationType.AWOS3P))
        expect(station04V.stateCode).to(equal("CO"))
        expect(station04V.city).to(equal("SAGUACHE"))

        // Verify AWOS-AV station
        guard let station06U = stations.first(where: { $0.stationId == "06U" }) else {
          fail("06U station not found")
          return
        }
        expect(station06U.type).to(equal(WeatherStation.StationType.AWOSAV))
        expect(station06U.stateCode).to(equal("NV"))

        // Verify station with survey method
        guard let station04W = stations.first(where: { $0.stationId == "04W" }) else {
          fail("04W station not found")
          return
        }
        expect(station04W.surveyMethod).to(equal(SurveyMethod.estimated))
      }
    }
  }
}
