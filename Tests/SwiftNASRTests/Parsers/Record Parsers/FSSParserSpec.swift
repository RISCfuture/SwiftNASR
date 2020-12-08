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
            let NASR = SwiftNASR.fromLocalDirectory(distURL)

            beforeEach {
                let group = DispatchGroup()
                group.enter()
                NASR.load { _ in group.leave() }
                group.wait()
            }

            it("parses FSSes") {
                try! NASR.parse(.flightServiceStations)
                expect(NASR.data.FSSes!.count).to(equal(2))
                
                let FTW = NASR.data.FSSes!.first(where: { $0.ID == "FTW" })!
                expect(FTW.commFacilities.count).to(equal(20))
                expect(FTW.navaids.count).to(equal(79))
            }
        }
    }
}
