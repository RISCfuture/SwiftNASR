import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class PreferredRouteParserSpec: AsyncSpec {
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

      it("parses preferred routes") {
        try await nasr.parse(RecordType.preferredRoutes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let routes = await nasr.data.preferredRoutes else {
          fail("No routes parsed")
          return
        }

        // PFR.txt has 3 routes: ABE-ACY, ABE-ALB, ABE-AVP
        expect(routes.count).to(equal(3))

        // Find ABE-ACY TEC route
        guard
          let abeAcy = routes.first(where: {
            $0.originIdentifier == "ABE" && $0.destinationIdentifier == "ACY"
          })
        else {
          fail("ABE-ACY route not found")
          return
        }

        expect(abeAcy.routeType).to(equal(PreferredRoute.RouteType.towerEnrouteControl))
        expect(abeAcy.sequenceNumber).to(equal(1))
        expect(abeAcy.routeTypeDescription).to(equal("TOWER ENROUTE CONTROL"))
        expect(abeAcy.altitudeDescription).to(equal("5000"))
      }

      it("parses route segments") {
        try await nasr.parse(RecordType.preferredRoutes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let routes = await nasr.data.preferredRoutes else {
          fail("No routes parsed")
          return
        }

        // Find ABE-ACY TEC route
        guard
          let abeAcy = routes.first(where: {
            $0.originIdentifier == "ABE" && $0.destinationIdentifier == "ACY"
          })
        else {
          fail("ABE-ACY route not found")
          return
        }

        // Should have 3 segments: FJC, ARD, CYN
        expect(abeAcy.segments.count).to(equal(3))

        // First segment should be FJC VORTAC with radial only
        if let firstSeg = abeAcy.segments.first {
          expect(firstSeg.sequenceNumber).to(equal(5))
          expect(firstSeg.identifier).to(equal("FJC"))
          expect(firstSeg.segmentType).to(equal(PreferredRoute.SegmentType.navaid))
          expect(firstSeg.navaidType).to(equal(NavaidFacilityType.VORTAC))
          expect(firstSeg.navaidTypeDescription).to(equal("VORTAC"))
          expect(firstSeg.radialDistance).to(equal(PreferredRoute.RadialDistance.radial(90)))
        }

        // Second segment should be ARD VOR/DME with radial and distance
        if abeAcy.segments.count > 1 {
          let secondSeg = abeAcy.segments[1]
          expect(secondSeg.identifier).to(equal("ARD"))
          expect(secondSeg.navaidType).to(equal(NavaidFacilityType.VOR_DME))
          expect(secondSeg.radialDistance).to(
            equal(PreferredRoute.RadialDistance.radialDistance(radial: 270, distance: 15))
          )
        }

        // Third segment should have no radial/distance
        if abeAcy.segments.count > 2 {
          let thirdSeg = abeAcy.segments[2]
          expect(thirdSeg.identifier).to(equal("CYN"))
          expect(thirdSeg.radialDistance).to(beNil())
        }
      }

      it("parses fix segments with state codes") {
        try await nasr.parse(RecordType.preferredRoutes) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let routes = await nasr.data.preferredRoutes else {
          fail("No routes parsed")
          return
        }

        // Find ABE-ALB route (has a FIX segment)
        guard
          let abeAlb = routes.first(where: {
            $0.originIdentifier == "ABE" && $0.destinationIdentifier == "ALB"
          })
        else {
          fail("ABE-ALB route not found")
          return
        }

        // Second segment should be LAAYK fix
        if abeAlb.segments.count > 1 {
          let fixSeg = abeAlb.segments[1]
          expect(fixSeg.identifier).to(equal("LAAYK"))
          expect(fixSeg.segmentType).to(equal(PreferredRoute.SegmentType.fix))
          expect(fixSeg.fixStateCode).to(equal("PA"))
        }
      }
    }
  }
}
