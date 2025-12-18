import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class MiscActivityAreaParserSpec: AsyncSpec {
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

      it("parses miscellaneous activity areas") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        expect(areas.count).to(equal(3))
      }

      it("parses aerobatic practice area correctly") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        let area = areas.first { $0.MAAId == "AA0001" }
        expect(area).toNot(beNil())
        expect(area?.areaType).to(equal(.aerobaticPractice))
        expect(area?.stateCode).to(equal("CA"))
        expect(area?.stateName).to(equal("CALIFORNIA"))
        expect(area?.city).to(equal("SAN JOSE"))
        expect(area?.areaName).to(equal("SAN JOSE AEROBATIC PRACTICE AREA"))
      }

      it("parses navaid reference") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        let area = areas.first { $0.MAAId == "AA0001" }
        expect(area?.navaidIdentifier).to(equal("SJC"))
        expect(area?.navaidFacilityType).to(equal("VORTAC"))
        expect(area?.navaidAzimuthDeg).to(beCloseTo(90.0, within: 0.1))
        expect(area?.navaidDistanceNM).to(beCloseTo(10.5, within: 0.1))
      }

      it("parses coordinates") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        // 37°22'01.5"N ≈ 134521.5 arc-seconds, 122°03'45.8"W ≈ -439425.8 arc-seconds
        let area = areas.first { $0.MAAId == "AA0001" }
        expect(area?.position?.latitudeArcsec).to(beCloseTo(134522, within: 10))
        expect(area?.position?.longitudeArcsec).to(beCloseTo(-439426, within: 10))
      }

      it("parses altitude limits") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        let area = areas.first { $0.MAAId == "AA0001" }
        expect(area?.maximumAltitude?.value).to(equal(5000))
        expect(area?.maximumAltitude?.datum).to(equal(.MSL))
        expect(area?.minimumAltitude?.value).to(equal(3000))
        expect(area?.minimumAltitude?.datum).to(equal(.AGL))
        expect(area?.areaRadiusNM).to(equal(5.0))
        expect(area?.isShownOnVFRChart).to(beTrue())
      }

      it("parses polygon coordinates") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        let area = areas.first { $0.MAAId == "AA0001" }
        expect(area?.polygonCoordinates.count).to(equal(4))
        // 37°25'00"N ≈ 134700 arc-seconds
        expect(area?.polygonCoordinates.first?.position?.latitudeArcsec).to(
          beCloseTo(134700, within: 10)
        )
      }

      it("parses times of use") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        let area = areas.first { $0.MAAId == "AA0001" }
        expect(area?.timesOfUse.count).to(equal(1))
        expect(area?.timesOfUse.first).to(equal("SUNRISE TO SUNSET LOCAL TIME"))
      }

      it("parses user groups") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        let area = areas.first { $0.MAAId == "AA0001" }
        expect(area?.userGroups.count).to(equal(1))
        expect(area?.userGroups.first).to(equal("SAN JOSE AEROBATIC CLUB"))
      }

      it("parses contact facilities") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        let area = areas.first { $0.MAAId == "AA0001" }
        expect(area?.contactFacilities.count).to(equal(1))
        expect(area?.contactFacilities.first?.facilityId).to(equal("NCT"))
        expect(area?.contactFacilities.first?.facilityName).to(equal("NORCAL APPROACH"))
        expect(area?.contactFacilities.first?.commercialFrequencyKHz).to(equal(124000))
        expect(area?.contactFacilities.first?.showCommercialOnChart).to(beTrue())
      }

      it("parses remarks") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        let area = areas.first { $0.MAAId == "AA0001" }
        expect(area?.remarks.count).to(equal(1))
        expect(area?.remarks.first).to(contain("NORCAL"))
      }

      it("parses glider area") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        let area = areas.first { $0.MAAId == "GL0002" }
        expect(area).toNot(beNil())
        expect(area?.areaType).to(equal(.glider))
        expect(area?.city).to(equal("LIVERMORE"))
      }

      it("parses space launch area with nearest airport") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        let area = areas.first { $0.MAAId == "SL0003" }
        expect(area).toNot(beNil())
        expect(area?.areaType).to(equal(.spaceLaunch))
        expect(area?.nearestAirportId).to(equal("SMX"))
        expect(area?.nearestAirportDistanceNM).to(beCloseTo(15.5, within: 0.1))
        expect(area?.nearestAirportDirection).to(equal(.northwest))
      }

      it("parses check for NOTAMs") {
        try await nasr.parse(RecordType.miscActivityAreas) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let areas = await nasr.data.miscActivityAreas else {
          fail("miscActivityAreas is nil")
          return
        }

        let area = areas.first { $0.MAAId == "SL0003" }
        expect(area?.checkForNOTAMs.count).to(equal(2))
        expect(area?.checkForNOTAMs).to(contain("VBG"))
        expect(area?.checkForNOTAMs).to(contain("SMX"))
      }
    }
  }
}
