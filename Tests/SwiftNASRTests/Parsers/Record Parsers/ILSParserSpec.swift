import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class ILSParserSpec: AsyncSpec {
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

      it("parses ILS facilities") {
        try await nasr.parse(RecordType.ILSes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let ILSFacilities = await nasr.data.ILSFacilities else {
          fail()
          return
        }
        // ILS.txt has 2 ILS facilities: ANB and AUO
        expect(ILSFacilities.count).to(equal(2))

        // Verify ANB ILS (runway 05)
        guard let anb = ILSFacilities.first(where: { $0.ILSId == "I-ANB" }) else {
          fail("ANB ILS not found")
          return
        }
        expect(anb.airportSiteNumber).to(equal("00128.*A"))
        expect(anb.runwayEndId).to(equal("05"))
        expect(anb.systemType).to(equal(ILS.SystemType.ILS))
        expect(anb.airportName).to(equal("ANNISTON RGNL"))
        expect(anb.city).to(equal("ANNISTON"))
        expect(anb.stateCode).to(equal("AL"))
        expect(anb.stateName).to(equal("ALABAMA"))
        expect(anb.regionCode).to(equal("ASO"))
        expect(anb.airportId).to(equal("ANB"))
        expect(anb.runwayLength).to(equal(7000))
        expect(anb.runwayWidth).to(equal(150))
        expect(anb.category).to(equal(ILS.Category.I))
        expect(anb.owner).to(equal("FEDERAL AVIATION ADMIN."))
        expect(anb.operator).to(equal("FEDERAL AVIATION ADMIN."))
        expect(anb.approachBearing?.value).to(beCloseTo(52.45, within: 0.01))
        expect(anb.approachBearing?.reference).to(equal(.magnetic))
        expect(anb.magneticVariation).to(equal(-4))

        // Verify localizer
        expect(anb.localizer).notTo(beNil())
        expect(anb.localizer?.status).to(equal(OperationalStatus.operationalRestricted))
        expect(anb.localizer?.frequency).to(equal(111500))
        // Position: 33-35-47.260N = 33*3600 + 35*60 + 47.260 = 120947.26 arc-seconds
        expect(anb.localizer?.position?.latitude).to(beCloseTo(120947.26, within: 0.01))
        // 085-50-48.960W = -(85*3600 + 50*60 + 48.960) = -309048.96 arc-seconds
        expect(anb.localizer?.position?.longitude).to(beCloseTo(-309048.96, within: 0.01))
        expect(anb.localizer?.distanceFromApproachEnd).to(equal(-8050))
        expect(anb.localizer?.distanceFromCenterline).to(equal(-1))  // negative = left
        expect(anb.localizer?.position?.elevation).to(beCloseTo(612.1, within: 0.1))
        expect(anb.localizer?.courseWidth).to(beCloseTo(5.80, within: 0.01))
        expect(anb.localizer?.distanceFromStopEnd).to(equal(1050))
        expect(anb.localizer?.serviceCode).to(equal(ILS.LocalizerServiceCode.noVoice))

        // Verify glide slope
        expect(anb.glideSlope).notTo(beNil())
        expect(anb.glideSlope?.status).to(equal(OperationalStatus.operationalIFR))
        expect(anb.glideSlope?.glideSlopeType).to(equal(ILS.GlideSlope.GlidePathType.glideSlope))
        expect(anb.glideSlope?.angle).to(beCloseTo(3.0, within: 0.01))
        expect(anb.glideSlope?.frequency).to(equal(332900))
        expect(anb.glideSlope?.position?.elevation).to(beCloseTo(590.8, within: 0.1))

        // Verify markers
        expect(anb.markers.count).to(equal(2))
        // Check outer marker
        guard let outerMarker = anb.markers.first(where: { $0.markerType == .outer }) else {
          fail("Outer marker not found")
          return
        }
        expect(outerMarker.status).to(equal(OperationalStatus.operationalIFR))
        expect(outerMarker.facilityType).to(equal(ILS.MarkerBeacon.MarkerFacilityType.markerNDB))
        expect(outerMarker.locationId).to(equal("AN"))
        expect(outerMarker.name).to(equal("BOGGA"))
        expect(outerMarker.frequency).to(equal(211))
        expect(outerMarker.collocatedNavaid).to(equal("AN*NDB"))

        // Check middle marker (decommissioned)
        guard let middleMarker = anb.markers.first(where: { $0.markerType == .middle }) else {
          fail("Middle marker not found")
          return
        }
        expect(middleMarker.status).to(equal(OperationalStatus.decommissioned))
        expect(middleMarker.facilityType).to(equal(ILS.MarkerBeacon.MarkerFacilityType.marker))

        // Verify remarks
        expect(anb.remarks.count).to(equal(2))
        expect(anb.remarks).to(contain("ILS CLASSIFICATION CODE IA"))
        expect(anb.remarks).to(contain("LOC UNUSBL WI 0.6 NM; BYD 16 DEGS RIGHT OF CRS."))

        // Verify AUO ILS (runway 36)
        guard let auo = ILSFacilities.first(where: { $0.ILSId == "I-AUO" }) else {
          fail("AUO ILS not found")
          return
        }
        expect(auo.airportSiteNumber).to(equal("00146.*A"))
        expect(auo.runwayEndId).to(equal("36"))
        expect(auo.airportName).to(equal("AUBURN UNIVERSITY RGNL"))
        expect(auo.localizer?.frequency).to(equal(110100))
        expect(auo.glideSlope?.angle).to(beCloseTo(3.0, within: 0.01))
        expect(auo.markers.count).to(equal(0))  // No markers for AUO in mock data
      }
    }
  }
}
