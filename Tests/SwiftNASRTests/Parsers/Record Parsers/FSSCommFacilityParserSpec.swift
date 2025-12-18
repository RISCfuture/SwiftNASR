import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class FSSCommFacilityParserSpec: AsyncSpec {
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

      it("parses FSS communication facilities") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        expect(facilities.count).to(equal(4))
      }

      it("parses outlet identification") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        let facility = facilities.first { $0.outletIdentifier == "OAK" }
        expect(facility).toNot(beNil())
        expect(facility?.outletType).to(equal(.rco))
      }

      it("parses associated navaid") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        let facility = facilities.first { $0.outletIdentifier == "OAK" }
        expect(facility?.navaidIdentifier).to(equal("OAK"))
        expect(facility?.navaidType).to(equal(NavaidFacilityType.VOR_DME))
        expect(facility?.navaidCity).to(equal("OAKLAND"))
        expect(facility?.navaidName).to(equal("OAKLAND"))
      }

      it("parses outlet location") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        let facility = facilities.first { $0.outletIdentifier == "OAK" }
        expect(facility?.outletCity).to(equal("OAKLAND"))
        expect(facility?.outletState).to(equal("CALIFORNIA"))
        expect(facility?.regionName).to(equal("WESTERN PACIFIC"))
        expect(facility?.regionCode).to(equal("AWP"))
      }

      it("parses coordinates") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        // 37°43'30"N ≈ 135810 arc-seconds, 122°13'30"W ≈ -440010 arc-seconds
        let facility = facilities.first { $0.outletIdentifier == "OAK" }
        expect(facility?.outletPosition?.latitudeArcsec).to(beCloseTo(135810, within: 100))
        expect(facility?.outletPosition?.longitudeArcsec).to(beCloseTo(-440010, within: 100))
      }

      it("parses frequencies") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        let facility = facilities.first { $0.outletIdentifier == "OAK" }
        expect(facility?.frequencies.count).to(equal(3))
        // 122.2 MHz = 122200 kHz, 122.55 MHz = 122550 kHz
        expect(facility?.frequencies.map(\.frequencyKHz)).to(contain(122200))
        expect(facility?.frequencies.map(\.frequencyKHz)).to(contain(122550))
        // All OAK frequencies should have no use restriction
        expect(facility?.frequencies.allSatisfy { $0.use == nil }).to(beTrue())
      }

      it("parses receive-only frequencies") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        let facility = facilities.first { $0.outletIdentifier == "LVK" }
        expect(facility?.frequencies.count).to(equal(2))
        // 122.35R MHz = 122350 kHz receive-only
        let receiveOnlyFreq = facility?.frequencies.first { $0.frequencyKHz == 122350 }
        expect(receiveOnlyFreq?.use).to(equal(.receiveOnly))
        // 122.5 MHz = 122500 kHz normal
        let normalFreq = facility?.frequencies.first { $0.frequencyKHz == 122500 }
        expect(normalFreq?.use).to(beNil())
      }

      it("parses FSS information") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        let facility = facilities.first { $0.outletIdentifier == "OAK" }
        expect(facility?.FSSIdentifier).to(equal("OAK"))
        expect(facility?.FSSName).to(equal("OAKLAND FLIGHT SERVICE"))
        expect(facility?.alternateFSSIdentifier).to(equal("RNO"))
        expect(facility?.alternateFSSName).to(equal("RENO FLIGHT SERVICE"))
      }

      it("parses operational hours") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        let facility = facilities.first { $0.outletIdentifier == "OAK" }
        expect(facility?.operationalHours).to(contain("0600-2200"))
      }

      it("parses owner and operator") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        let facility = facilities.first { $0.outletIdentifier == "OAK" }
        expect(facility?.ownerCode).to(equal("F"))
        expect(facility?.ownerName).to(contain("FEDERAL AVIATION"))
        expect(facility?.operatorCode).to(equal("F"))
      }

      it("parses status and timezone") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        let facility = facilities.first { $0.outletIdentifier == "OAK" }
        expect(facility?.timeZone).to(equal(.pacific))
        expect(facility?.status).to(equal(.operationalIFR))
      }

      it("parses RCO1 outlet type") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        let facility = facilities.first { $0.outletIdentifier == "LVK" }
        expect(facility).toNot(beNil())
        expect(facility?.outletType).to(equal(.rco1))
      }

      it("parses facilities from different regions") {
        try await nasr.parse(RecordType.FSSCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let facilities = await nasr.data.FSSCommFacilities else {
          fail("FSSCommFacilities is nil")
          return
        }

        let jfkFacility = facilities.first { $0.outletIdentifier == "JFK" }
        expect(jfkFacility).toNot(beNil())
        expect(jfkFacility?.regionName).to(equal("EASTERN"))
        expect(jfkFacility?.regionCode).to(equal("AEA"))
        expect(jfkFacility?.timeZone).to(equal(.eastern))
      }
    }
  }
}
