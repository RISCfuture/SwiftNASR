import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class DepartureArrivalProcedureCompleteParserSpec: AsyncSpec {
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

      it("parses complete departure/arrival procedures") {
        try await nasr.parse(RecordType.departureArrivalProceduresComplete) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let procedures = await nasr.data.departureArrivalProceduresComplete else {
          fail("No procedures parsed")
          return
        }

        // STARDP.txt has STAR procedures starting with S0001
        expect(procedures.count).to(beGreaterThan(0))

        // Find S0001 procedure (AALLE THREE STAR)
        guard let aalle = procedures.first(where: { $0.sequenceNumber == "S0001" }) else {
          fail("S0001 procedure not found")
          return
        }

        expect(aalle.procedureType).to(equal(DepartureArrivalProcedure.ProcedureType.STAR))
        expect(aalle.computerCode).to(equal("AALLE.AALLE3"))
        expect(aalle.name).to(equal("AALLE THREE"))

        // Verify points in the procedure
        expect(aalle.points.count).to(beGreaterThan(0))

        // First point should be AALLE waypoint
        if let firstPoint = aalle.points.first {
          expect(firstPoint.fixType).to(equal(DepartureArrivalProcedure.FixType.waypoint))
          expect(firstPoint.identifier).to(equal("AALLE"))
        }

        // Should have adapted airport DEN
        expect(aalle.adaptedAirports.count).to(beGreaterThan(0))
        let den = aalle.adaptedAirports.first { $0.identifier == "DEN" }
        expect(den).notTo(beNil())
      }

      it("parses waypoint coordinates correctly") {
        try await nasr.parse(RecordType.departureArrivalProceduresComplete) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let procedures = await nasr.data.departureArrivalProceduresComplete else {
          fail("No procedures parsed")
          return
        }

        guard let aalle = procedures.first(where: { $0.sequenceNumber == "S0001" }) else {
          fail("S0001 procedure not found")
          return
        }

        // First point AALLE should have coordinates N4027123W10345252
        // N40°27'12.3" = 40.4534... degrees × 3600 = 145632.24 arc-seconds
        // W103°45'25.2" = -103.757... degrees × 3600 = -373525.2 arc-seconds
        if let firstPoint = aalle.points.first {
          expect(firstPoint.position.latitudeArcsec).to(beCloseTo(145632.24, within: 36))
          expect(firstPoint.position.longitudeArcsec).to(beCloseTo(-373525.2, within: 36))
        }
      }
    }
  }
}
