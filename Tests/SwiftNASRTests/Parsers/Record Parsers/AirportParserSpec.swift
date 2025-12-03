import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class AirportParserSpec: AsyncSpec {
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

      it("parses airports, runways, attendance schedules, and remarks") {
        try await nasr.parse(
          .airports,
          withProgress: { _ in },
          errorHandler: { _ in
            //                    fail(error.localizedDescription)
            return true
          }
        )

        guard let airports = await nasr.data.airports else {
          fail()
          return
        }
        expect(airports.count).to(equal(2))

        guard let SQL = airports.first(where: { $0.LID == "SQL" }) else {
          fail()
          return
        }
        expect(SQL.runways.count).to(equal(1))
        expect(SQL.runways[0].reciprocalEnd).notTo(beNil())
        expect(SQL.remarks.forField(Airport.Field.trafficPatternAltitude).count).to(equal(1))
        expect(SQL.runways[0].baseEnd.remarks.forField(RunwayEnd.Field.rightTraffic).count).to(
          equal(1)
        )
        expect(SQL.attendanceSchedule.count).to(equal(1))
      }
    }
  }
}
