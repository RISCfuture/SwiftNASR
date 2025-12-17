import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class TerminalCommFacilityParserSpec: AsyncSpec {
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

      it("parses terminal comm facilities") {
        try await nasr.parse(RecordType.terminalCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let facilities = await nasr.data.terminalCommFacilities else {
          fail()
          return
        }
        // TWR.txt has 4 facilities: ADK, AKK, AKI, 7AK
        expect(facilities.count).to(equal(4))

        // Verify ADK facility
        guard let adk = facilities.first(where: { $0.facilityId == "ADK" }) else {
          fail("ADK facility not found")
          return
        }
        expect(adk.airportSiteNumber).to(equal("50009.*A"))
        expect(adk.stateCode).to(equal("AK"))
        expect(adk.stateName).to(equal("ALASKA"))
        expect(adk.city).to(equal("ADAK ISLAND"))
        expect(adk.airportName).to(equal("ADAK"))
        expect(adk.facilityType).to(equal(TerminalCommFacility.FacilityType.nonATCT))
        expect(adk.tieInFSSId).to(equal("CDB"))
        expect(adk.tieInFSSName).to(equal("COLD BAY"))

        // Verify radar data from TWR5
        expect(adk.radar).notTo(beNil())
        expect(adk.radar?.primaryApproachRadar).to(equal(TerminalCommFacility.RadarType.nonRadar))
        expect(adk.radar?.primaryDepartureRadar).to(equal(TerminalCommFacility.RadarType.nonRadar))

        // Verify remarks from TWR6
        expect(adk.remarks.count).to(equal(1))
        expect(adk.remarks.first).to(contain("APCH/DEP SVC PRVDD BY ANCHORAGE ARTCC"))
      }

      it("parses AKK facility with RADAR service") {
        try await nasr.parse(RecordType.terminalCommFacilities) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let facilities = await nasr.data.terminalCommFacilities else {
          fail()
          return
        }

        guard let akk = facilities.first(where: { $0.facilityId == "AKK" }) else {
          fail("AKK facility not found")
          return
        }
        expect(akk.facilityType).to(equal(TerminalCommFacility.FacilityType.nonATCT))
        expect(akk.radar?.primaryApproachRadar).to(equal(TerminalCommFacility.RadarType.radar))
        expect(akk.radar?.primaryDepartureRadar).to(equal(TerminalCommFacility.RadarType.radar))
      }
    }
  }
}
