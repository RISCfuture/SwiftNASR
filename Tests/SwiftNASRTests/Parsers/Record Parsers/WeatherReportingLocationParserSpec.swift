import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class WeatherReportingLocationParserSpec: AsyncSpec {
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

      it("parses weather reporting locations") {
        try await nasr.parse(RecordType.weatherReportingLocations) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let locations = await nasr.data.weatherReportingLocations else {
          fail("No locations parsed")
          return
        }

        // WXL.txt has 10 locations
        expect(locations.count).to(equal(10))

        // Find A08 location
        guard let a08 = locations.first(where: { $0.identifier == "A08" }) else {
          fail("A08 location not found")
          return
        }

        expect(a08.city).to(equal("MARION"))
        expect(a08.stateCode).to(equal("AL"))
        expect(a08.position?.elevation).to(equal(215))
        expect(a08.elevationAccuracy).to(equal(.estimated))
      }

      it("parses coordinates correctly") {
        try await nasr.parse(RecordType.weatherReportingLocations) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let locations = await nasr.data.weatherReportingLocations else {
          fail("No locations parsed")
          return
        }

        // Find A08: 3231001N 08723071W
        // 32°31'00.1"N = 32*3600 + 31*60 + 0.1 = 117060.1 arc-seconds
        // 87°23'07.1"W = -(87*3600 + 23*60 + 7.1) = -314587.1 arc-seconds
        guard let a08 = locations.first(where: { $0.identifier == "A08" }) else {
          fail("A08 location not found")
          return
        }

        expect(a08.position?.latitude).to(beCloseTo(117060.1, within: 1))
        expect(a08.position?.longitude).to(beCloseTo(-314587.1, within: 1))
      }

      it("parses weather services") {
        try await nasr.parse(RecordType.weatherReportingLocations) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let locations = await nasr.data.weatherReportingLocations else {
          fail("No locations parsed")
          return
        }

        // A08 has: METAR NOTAM UA
        guard let a08 = locations.first(where: { $0.identifier == "A08" }) else {
          fail("A08 location not found")
          return
        }

        expect(a08.weatherServices.count).to(equal(3))
        expect(a08.weatherServices).to(contain(.METAR))
        expect(a08.weatherServices).to(contain(.NOTAM))
        expect(a08.weatherServices).to(contain(.PIREP))
      }

      it("parses locations with multiple services") {
        try await nasr.parse(RecordType.weatherReportingLocations) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let locations = await nasr.data.weatherReportingLocations else {
          fail("No locations parsed")
          return
        }

        // ABI has: FD FT NOTAM SA UA
        guard let abi = locations.first(where: { $0.identifier == "ABI" }) else {
          fail("ABI location not found")
          return
        }

        expect(abi.weatherServices.count).to(equal(5))
        expect(abi.weatherServices).to(contain(.windsAloft))
        expect(abi.weatherServices).to(contain(.terminalForecast))
        expect(abi.weatherServices).to(contain(.NOTAM))
        expect(abi.weatherServices).to(contain(.surfaceObservation))
        expect(abi.weatherServices).to(contain(.PIREP))
      }

      it("parses surveyed elevation") {
        try await nasr.parse(RecordType.weatherReportingLocations) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let locations = await nasr.data.weatherReportingLocations else {
          fail("No locations parsed")
          return
        }

        // A39 has surveyed elevation (S)
        guard let a39 = locations.first(where: { $0.identifier == "A39" }) else {
          fail("A39 location not found")
          return
        }

        expect(a39.position?.elevation).to(equal(1283))
        expect(a39.elevationAccuracy).to(equal(.surveyed))
      }

      it("handles locations with no weather services") {
        try await nasr.parse(RecordType.weatherReportingLocations) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let locations = await nasr.data.weatherReportingLocations else {
          fail("No locations parsed")
          return
        }

        // ABC has no weather services (blank field)
        guard let abc = locations.first(where: { $0.identifier == "ABC" }) else {
          fail("ABC location not found")
          return
        }

        expect(abc.weatherServices.count).to(equal(0))
      }
    }
  }
}
