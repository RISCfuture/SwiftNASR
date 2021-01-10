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
            let nasr = NASR.fromLocalDirectory(distURL)

            beforeEach {
                let group = DispatchGroup()
                group.enter()
                nasr.load { _ in group.leave() }
                group.wait()
            }

            it("parses airports, runways, attendance schedules, and remarks") {
                try! nasr.parse(.airports) { _ in false }
                expect(nasr.data.airports!.count).to(equal(2))
                
                let SQL = nasr.data.airports!.first(where: { $0.LID == "SQL" })!
                expect(SQL.runways.count).to(equal(1))
                expect(SQL.runways[0].reciprocalEnd).notTo(beNil())
                expect(SQL.remarks.forField(.trafficPatternAltitude).count).to(equal(1))
                expect(SQL.runways[0].baseEnd.remarks.forField(.rightTraffic).count).to(equal(1))
                expect(SQL.attendanceSchedule.count).to(equal(1))
            }
            
            it("returns a Publisher") {
                let publisher = nasr.parseAirports()
                _ = publisher.sink(receiveCompletion: { _ in }, receiveValue: { airports in
                    expect(airports.count).to(equal(2))
                })
                expect(nasr.data.airports!.count).toEventually(equal(2))
            }
        }
    }
}
