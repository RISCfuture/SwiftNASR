import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class FSSParserSpec: QuickSpec {
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

            it("parses FSSes") {
                try! nasr.parse(.flightServiceStations) { _ in false }
                expect(nasr.data.FSSes!.count).to(equal(2))
                
                let FTW = nasr.data.FSSes!.first(where: { $0.ID == "FTW" })!
                expect(FTW.commFacilities.count).to(equal(20))
                expect(FTW.navaids.count).to(equal(79))
            }
            
            it("returns a Publisher") {
                let publisher = nasr.parseFSSes()
                _ = publisher.sink(receiveCompletion: { _ in }, receiveValue: { FSSes in
                    expect(FSSes.count).to(equal(2))
                })
                expect(nasr.data.FSSes!.count).toEventually(equal(2))
            }
        }
    }
}
