import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class AirwayParserSpec: AsyncSpec {
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

      it("parses airways") {
        try await nasr.parse(RecordType.airways) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let airways = await nasr.data.airways else {
          fail()
          return
        }
        // AWY.txt has 3 unique airways: A16, B9, G13
        expect(airways.count).to(equal(3))

        // Verify A16 airway (Amber colored = Federal type, "A" prefix indicates color not region)
        guard let a16 = airways.first(where: { $0.designation == "A16" }) else {
          fail("A16 airway not found")
          return
        }
        expect(a16.type).to(equal(Airway.AirwayType.federal))
        expect(a16.segments.count).to(equal(2))

        // Verify first segment of A16
        if let firstSegment = a16.segments.first {
          expect(firstSegment.sequenceNumber).to(equal(10))
          expect(firstSegment.altitudes.MEA).to(equal(3000))
          expect(firstSegment.distanceToNext).to(beCloseTo(22.7, within: 0.1))
          expect(firstSegment.magneticCourse).to(beCloseTo(53.79, within: 0.01))
          expect(firstSegment.magneticCourseOpposite).to(beCloseTo(234.2, within: 0.01))

          // Note: Changeover points come from AWY3 records, which aren't in mock data
          // So we don't expect changeover point to be present
        }

        // Verify B9 airway (Federal)
        guard let b9 = airways.first(where: { $0.designation == "B9" }) else {
          fail("B9 airway not found")
          return
        }
        expect(b9.type).to(equal(Airway.AirwayType.federal))
        expect(b9.segments.count).to(equal(2))

        // Verify B9 has segment with point type
        if let firstSegment = b9.segments.first {
          expect(firstSegment.point.name).to(equal("DEEDS"))
          expect(firstSegment.point.pointType).to(equal(.reportingPoint))
          expect(firstSegment.distanceToNext).to(beCloseTo(76.1, within: 0.1))
          expect(firstSegment.altitudes.MEA).to(equal(2000))
        }

        // Verify G13 airway
        guard let g13 = airways.first(where: { $0.designation == "G13" }) else {
          fail("G13 airway not found")
          return
        }
        expect(g13.type).to(equal(Airway.AirwayType.federal))
        expect(g13.segments.count).to(equal(1))

        if let firstSegment = g13.segments.first {
          expect(firstSegment.point.name).to(equal("ZOLMN"))
          expect(firstSegment.altitudes.MEA).to(equal(2000))
        }
      }
    }
  }
}
