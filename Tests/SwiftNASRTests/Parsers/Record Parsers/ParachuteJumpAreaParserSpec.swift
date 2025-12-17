import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class ParachuteJumpAreaParserSpec: AsyncSpec {
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

      it("parses parachute jump areas") {
        try await nasr.parse(RecordType.parachuteJumpAreas) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let areas = await nasr.data.parachuteJumpAreas else {
          fail("No areas parsed")
          return
        }

        // PJA.txt has 4 unique areas (PAK005, PAK006, PAK013, PAK016)
        expect(areas.count).to(equal(4))

        // Find PAK005 area
        guard let pak005 = areas.first(where: { $0.PJAId == "PAK005" }) else {
          fail("PAK005 area not found")
          return
        }

        expect(pak005.navaidIdentifier).to(equal("TED"))
        expect(pak005.navaidFacilityTypeCode).to(equal("D"))
        expect(pak005.navaidFacilityType).to(equal("VOR/DME"))
        expect(pak005.stateCode).to(equal("AK"))
        expect(pak005.stateName).to(equal("ALASKA"))
        expect(pak005.city).to(equal("ANCHORAGE"))
      }

      it("parses coordinates correctly") {
        try await nasr.parse(RecordType.parachuteJumpAreas) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let areas = await nasr.data.parachuteJumpAreas else {
          fail("No areas parsed")
          return
        }

        // Find PAK005: 61-18-47.4645N, 149-33-55.9086W
        guard let pak005 = areas.first(where: { $0.PJAId == "PAK005" }) else {
          fail("PAK005 area not found")
          return
        }

        // 61°18'47.4645"N = 61*3600 + 18*60 + 47.4645 ≈ 220727.46 arc-seconds
        expect(pak005.position?.latitude).to(beCloseTo(220727.46, within: 1))
        // 149°33'55.9086"W = -(149*3600 + 33*60 + 55.9086) ≈ -538435.91 arc-seconds
        expect(pak005.position?.longitude).to(beCloseTo(-538435.91, within: 1))
      }

      it("parses altitude and charting info") {
        try await nasr.parse(RecordType.parachuteJumpAreas) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let areas = await nasr.data.parachuteJumpAreas else {
          fail("No areas parsed")
          return
        }

        guard let pak005 = areas.first(where: { $0.PJAId == "PAK005" }) else {
          fail("PAK005 area not found")
          return
        }

        expect(pak005.maxAltitude?.value).to(equal(12500))
        expect(pak005.maxAltitude?.datum).to(equal(.MSL))
        expect(pak005.sectionalChartingRequired).to(equal(false))
        expect(pak005.publishedInAFD).to(equal(true))
      }

      it("parses times of use") {
        try await nasr.parse(RecordType.parachuteJumpAreas) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let areas = await nasr.data.parachuteJumpAreas else {
          fail("No areas parsed")
          return
        }

        // PAK005 has PJA2 record with times of use
        guard let pak005 = areas.first(where: { $0.PJAId == "PAK005" }) else {
          fail("PAK005 area not found")
          return
        }

        expect(pak005.timesOfUse.count).to(equal(1))
        expect(pak005.timesOfUse.first).to(equal("SUNRISE-SUNSET; WEEKENDS"))
      }

      it("parses remarks") {
        try await nasr.parse(RecordType.parachuteJumpAreas) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let areas = await nasr.data.parachuteJumpAreas else {
          fail("No areas parsed")
          return
        }

        // PAK005 has PJA5 record with remarks
        guard let pak005 = areas.first(where: { $0.PJAId == "PAK005" }) else {
          fail("PAK005 area not found")
          return
        }

        expect(pak005.remarks.count).to(equal(1))
        expect(pak005.remarks.first).to(equal("JUMPS OVER PIPPEL FIELD"))
      }

      it("parses contact facilities") {
        try await nasr.parse(RecordType.parachuteJumpAreas) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let areas = await nasr.data.parachuteJumpAreas else {
          fail("No areas parsed")
          return
        }

        // PAK006 has PJA4 record with contact facility
        guard let pak006 = areas.first(where: { $0.PJAId == "PAK006" }) else {
          fail("PAK006 area not found")
          return
        }

        expect(pak006.contactFacilities.count).to(equal(1))
        if let facility = pak006.contactFacilities.first {
          expect(facility.facilityId).to(equal("ANC"))
          expect(facility.facilityName).to(contain("TED STEVENS ANCHORAGE"))
          expect(facility.commercialFrequency).to(equal(126400))
          expect(facility.commercialCharted).to(equal(false))
        }
      }

      it("parses drop zone and FSS info") {
        try await nasr.parse(RecordType.parachuteJumpAreas) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let areas = await nasr.data.parachuteJumpAreas else {
          fail("No areas parsed")
          return
        }

        guard let pak006 = areas.first(where: { $0.PJAId == "PAK006" }) else {
          fail("PAK006 area not found")
          return
        }

        expect(pak006.dropZoneName).to(equal("CAMPBELL"))
        expect(pak006.FSSIdentifier).to(equal("ENA"))
        expect(pak006.FSSName).to(equal("KENAI"))
      }
    }
  }
}
