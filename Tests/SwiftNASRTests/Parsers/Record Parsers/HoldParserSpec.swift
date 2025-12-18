import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class HoldParserSpec: AsyncSpec {
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

      it("parses holding patterns") {
        try await nasr.parse(RecordType.holds) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let holds = await nasr.data.holds else {
          fail("No holds parsed")
          return
        }

        // HPF.txt has 4 unique patterns (AABEE, AADEN, AALAN, AALLE)
        expect(holds.count).to(equal(4))

        // Find AABEE hold
        guard let aabee = holds.first(where: { $0.name.contains("AABEE") }) else {
          fail("AABEE hold not found")
          return
        }

        expect(aabee.patternNumber).to(equal(1))
        expect(aabee.effectiveDate).to(equal(DateComponents(year: 2021, month: 12, day: 30)))
        expect(aabee.holdingDirection).to(equal(CardinalDirection.northeast))
        expect(aabee.magneticBearingDeg).to(equal(26))
        expect(aabee.azimuthType).to(equal(Hold.AzimuthType.course))
        expect(aabee.inboundCourseDeg).to(equal(206))
        expect(aabee.turnDirection).to(equal(LateralDirection.left))
      }

      it("parses fix coordinates") {
        try await nasr.parse(RecordType.holds) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let holds = await nasr.data.holds else {
          fail("No holds parsed")
          return
        }

        guard let aabee = holds.first(where: { $0.name.contains("AABEE") }) else {
          fail("AABEE hold not found")
          return
        }

        expect(aabee.fixIdentifier).to(equal("AABEE"))
        expect(aabee.fixStateCode).to(equal("GA"))
        expect(aabee.fixICAORegion).to(equal("K7"))
        expect(aabee.fixARTCC).to(equal("ZTL"))

        // 34-04-05.000N = 34*3600 + 4*60 + 5 = 122645 arc-seconds
        expect(aabee.fixPosition?.latitudeArcsec).to(beCloseTo(122645, within: 10))
        // 084-12-51.710W = -(84*3600 + 12*60 + 51.71) = -303171.71 arc-seconds
        expect(aabee.fixPosition?.longitudeArcsec).to(beCloseTo(-303172, within: 10))
      }

      it("parses charting info") {
        try await nasr.parse(RecordType.holds) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let holds = await nasr.data.holds else {
          fail("No holds parsed")
          return
        }

        guard let aabee = holds.first(where: { $0.name.contains("AABEE") }) else {
          fail("AABEE hold not found")
          return
        }

        // HP2 record should have charting info
        expect(aabee.chartingInfo.count).to(equal(1))
        expect(aabee.chartingInfo.first).to(equal("IAP"))
      }

      it("parses other altitude/speed info") {
        try await nasr.parse(RecordType.holds) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let holds = await nasr.data.holds else {
          fail("No holds parsed")
          return
        }

        guard let aabee = holds.first(where: { $0.name.contains("AABEE") }) else {
          fail("AABEE hold not found")
          return
        }

        // HP3 record should have other altitude/speed
        expect(aabee.otherAltitudeSpeed.count).to(equal(1))
        expect(aabee.otherAltitudeSpeed.first).to(equal("130/54*200"))
      }

      it("parses leg length") {
        try await nasr.parse(RecordType.holds) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let holds = await nasr.data.holds else {
          fail("No holds parsed")
          return
        }

        // AADEN has "/15" leg distance (DME 15nm)
        guard let aaden = holds.first(where: { $0.name.contains("AADEN") }) else {
          fail("AADEN hold not found")
          return
        }

        expect(aaden.legDistanceNM).to(equal(15))
        expect(aaden.legTimeMin).to(beNil())
      }

      it("parses multiple charting records") {
        try await nasr.parse(RecordType.holds) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let holds = await nasr.data.holds else {
          fail("No holds parsed")
          return
        }

        // AADEN has 2 HP2 records (ENROUTE HIGH and STAR)
        guard let aaden = holds.first(where: { $0.name.contains("AADEN") }) else {
          fail("AADEN hold not found")
          return
        }

        expect(aaden.chartingInfo.count).to(equal(2))
        expect(aaden.chartingInfo).to(contain("ENROUTE HIGH"))
        expect(aaden.chartingInfo).to(contain("STAR"))
      }
    }
  }
}
