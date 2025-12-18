import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class MilitaryTrainingRouteParserSpec: AsyncSpec {
  override class func spec() {
    let distURL = Bundle.module.resourceURL!.appendingPathComponent(
      "MockDistribution",
      isDirectory: true
    )
    let nasr = NASR.fromLocalDirectory(distURL)

    describe("parse base data") {
      beforeEach {
        try await nasr.load()
      }

      it("parses military training routes") {
        try await nasr.parse(RecordType.militaryTrainingRoutes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let routes = await nasr.data.militaryTrainingRoutes else {
          fail("No routes parsed")
          return
        }

        // MTR.txt has 2 unique routes (IR002, VR12345)
        expect(routes.count).to(equal(2))
      }

      it("parses IFR route base data") {
        try await nasr.parse(RecordType.militaryTrainingRoutes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let routes = await nasr.data.militaryTrainingRoutes else {
          fail("No routes parsed")
          return
        }

        guard
          let ir002 = routes.first(where: { $0.routeIdentifier == "002" && $0.routeType == .IFR })
        else {
          fail("IR002 route not found")
          return
        }

        expect(ir002.routeType).to(equal(.IFR))
        expect(ir002.FAARegionCode).to(equal("AEA"))
        expect(ir002.timesOfUse).to(equal("CONTINUOUS"))
        expect(ir002.ARTCCIdentifiers).to(contain("ZTL"))
        expect(ir002.FSSIdentifiers).to(contain("AND"))
        expect(ir002.FSSIdentifiers).to(contain("BNA"))
      }

      it("parses VFR route base data") {
        try await nasr.parse(RecordType.militaryTrainingRoutes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let routes = await nasr.data.militaryTrainingRoutes else {
          fail("No routes parsed")
          return
        }

        guard
          let vr12345 = routes.first(where: {
            $0.routeIdentifier == "12345" && $0.routeType == .VFR
          })
        else {
          fail("VR12345 route not found")
          return
        }

        expect(vr12345.routeType).to(equal(.VFR))
        expect(vr12345.FAARegionCode).to(equal("ASW"))
        expect(vr12345.timesOfUse).to(equal("DAYLIGHT HOURS"))
        expect(vr12345.ARTCCIdentifiers).to(contain("TUL"))
      }
    }

    describe("parse procedures and descriptions") {
      beforeEach {
        try await nasr.load()
      }

      it("parses operating procedures") {
        try await nasr.parse(RecordType.militaryTrainingRoutes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let routes = await nasr.data.militaryTrainingRoutes else {
          fail("No routes parsed")
          return
        }

        guard
          let ir002 = routes.first(where: { $0.routeIdentifier == "002" && $0.routeType == .IFR })
        else {
          fail("IR002 route not found")
          return
        }

        expect(ir002.operatingProcedures.count).to(equal(2))
        expect(ir002.operatingProcedures.first).to(contain("ROUTE RESERVATION"))
      }

      it("parses route width descriptions") {
        try await nasr.parse(RecordType.militaryTrainingRoutes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let routes = await nasr.data.militaryTrainingRoutes else {
          fail("No routes parsed")
          return
        }

        guard
          let ir002 = routes.first(where: { $0.routeIdentifier == "002" && $0.routeType == .IFR })
        else {
          fail("IR002 route not found")
          return
        }

        expect(ir002.routeWidthDescriptions.count).to(equal(1))
        expect(ir002.routeWidthDescriptions.first).to(contain("10 NM"))
      }

      it("parses terrain following operations") {
        try await nasr.parse(RecordType.militaryTrainingRoutes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let routes = await nasr.data.militaryTrainingRoutes else {
          fail("No routes parsed")
          return
        }

        guard
          let ir002 = routes.first(where: { $0.routeIdentifier == "002" && $0.routeType == .IFR })
        else {
          fail("IR002 route not found")
          return
        }

        expect(ir002.terrainFollowingOperations.count).to(equal(1))
        expect(ir002.terrainFollowingOperations.first).to(contain("NOT AUTHORIZED"))
      }
    }

    describe("parse route points") {
      beforeEach {
        try await nasr.load()
      }

      it("parses route points") {
        try await nasr.parse(RecordType.militaryTrainingRoutes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let routes = await nasr.data.militaryTrainingRoutes else {
          fail("No routes parsed")
          return
        }

        guard
          let ir002 = routes.first(where: { $0.routeIdentifier == "002" && $0.routeType == .IFR })
        else {
          fail("IR002 route not found")
          return
        }

        expect(ir002.routePoints.count).to(equal(2))

        // Check point A
        guard let pointA = ir002.routePoints.first(where: { $0.pointId == "A" }) else {
          fail("Point A not found")
          return
        }

        expect(pointA.navaidIdentifier).to(equal("GQO"))
        expect(pointA.navaidBearingDeg).to(equal(270))
        expect(pointA.navaidDistanceNM).to(equal(12))
        // 35-45-30.0000N = 35*3600 + 45*60 + 30 = 128730 arc-seconds
        expect(pointA.position?.latitudeArcsec).to(beCloseTo(128730, within: 10))
        // 084-20-15.0000W = -(84*3600 + 20*60 + 15) = -303615 arc-seconds
        expect(pointA.position?.longitudeArcsec).to(beCloseTo(-303615, within: 10))
      }
    }

    describe("parse agencies") {
      beforeEach {
        try await nasr.load()
      }

      it("parses agencies") {
        try await nasr.parse(RecordType.militaryTrainingRoutes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let routes = await nasr.data.militaryTrainingRoutes else {
          fail("No routes parsed")
          return
        }

        guard
          let ir002 = routes.first(where: { $0.routeIdentifier == "002" && $0.routeType == .IFR })
        else {
          fail("IR002 route not found")
          return
        }

        expect(ir002.agencies.count).to(equal(2))

        // Check originating agency
        guard let originating = ir002.agencies.first(where: { $0.agencyType == .originating })
        else {
          fail("Originating agency not found")
          return
        }

        expect(originating.organizationName).to(contain("42ND FIGHTER WING"))
        expect(originating.station).to(equal("MAXWELL AFB"))
        expect(originating.city).to(equal("MONTGOMERY"))
        expect(originating.stateCode).to(equal("AL"))
        expect(originating.commercialPhone).to(contain("334-555-1234"))

        // Check scheduling agency
        guard let scheduling = ir002.agencies.first(where: { $0.agencyType == .scheduling1 }) else {
          fail("Scheduling agency not found")
          return
        }

        expect(scheduling.organizationName).to(contain("DOD SCHEDULING"))
        expect(scheduling.stateCode).to(equal("VA"))
        expect(scheduling.hours).to(contain("MON-FRI"))
      }
    }
  }
}
