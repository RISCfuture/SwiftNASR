import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class AirportParserSpec: QuickSpec {
    let fixturesURL = URL(fileURLWithPath: #file)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Support").appendingPathComponent("Fixtures")
    
    override func spec() {
        describe("parse") {
            let distURL = fixturesURL.appendingPathComponent("MockDistribution")
            let NASR = SwiftNASR.fromLocalDirectory(distURL)

            beforeEach {
                let group = DispatchGroup()
                group.enter()
                NASR.load { _ in group.leave() }
                group.wait()
            }

            it("parses airports, runways, attendance schedules, and remarks") {
                try! NASR.parse(.airports)
                expect(NASR.data.airports!.count).to(equal(2))
                
                let SQL = NASR.data.airports!.first(where: { $0.LID == "SQL" })!
                expect(SQL.runways.count).to(equal(1))
                expect(SQL.runways[0].reciprocalEnd).notTo(beNil())
                expect(SQL.remarks.forField(.trafficPatternAltitude).count).to(equal(1))
                expect(SQL.runways[0].baseEnd.remarks.forField(.rightTraffic).count).to(equal(1))
                expect(SQL.attendanceSchedule.count).to(equal(1))
            }
        }
    }
}
