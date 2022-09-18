import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class AirportParserSpec: QuickSpec {
    override func spec() {
        describe("parse") {
            let distURL = Bundle.module.resourceURL!.appendingPathComponent("MockDistribution", isDirectory: true)
            let nasr = NASR.fromLocalDirectory(distURL)

            beforeEach {
                waitUntil { done in
                    _ = nasr.load { result in
                        guard case let .failure(error) = result else { return }
                        fail((error as CustomStringConvertible).description)
                        done()
                    }
                }
            }

            it("parses airports, runways, attendance schedules, and remarks") {
                waitUntil { done in
                    try! nasr.parse(RecordType.airports, errorHandler: {
                        fail(($0 as CustomStringConvertible).description)
                        done()
                        return false
                    }, completionHandler: { done() })
                }
                expect(nasr.data.airports!.count).to(equal(2))
                
                let SQL = nasr.data.airports!.first(where: { $0.LID == "SQL" })!
                expect(SQL.runways.count).to(equal(1))
                expect(SQL.runways[0].reciprocalEnd).notTo(beNil())
                expect(SQL.remarks.forField(Airport.Field.trafficPatternAltitude).count).to(equal(1))
                expect(SQL.runways[0].baseEnd.remarks.forField(RunwayEnd.Field.rightTraffic).count).to(equal(1))
                expect(SQL.attendanceSchedule.count).to(equal(1))
            }
            
            it("returns a Publisher") {
                let publisher = nasr.parseAirportsPublisher()
                _ = publisher.sink(receiveCompletion: { _ in }, receiveValue: { airports in
                    expect(airports.count).to(equal(2))
                })
                expect(nasr.data.airports!.count).toEventually(equal(2))
            }
        }
    }
}
