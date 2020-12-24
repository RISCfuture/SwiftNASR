import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class ARTCCParserSpec: QuickSpec {
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

            it("parses centers, frequencies, and remarks") {
                try! NASR.parse(.ARTCCFacilities) { _ in false }
                expect(NASR.data.ARTCCs!.count).to(equal(94))
                
                let anchorage = NASR.data.ARTCCs!.first(where: { $0.ID == "ZAN" && $0.locationName == "ANCHORAGE" && $0.type == .ARTCC })!
                expect(anchorage.remarks.general.count).to(equal(9))
                expect(anchorage.frequencies.count).to(equal(4))
                
                let dillingham = NASR.data.ARTCCs!.first(where: { $0.ID == "ZAN" && $0.locationName == "DILLINGHAM" && $0.type == .RCAG })!
                expect(dillingham.frequencies[0].remarks.general.count).to(equal(1))
            }
            
            it("returns a Publisher") {
                let publisher = NASR.parseARTCCs()
                _ = publisher.sink(receiveCompletion: { _ in }, receiveValue: { ARTCCs in
                    expect(ARTCCs.count).to(equal(94))
                })
                expect(NASR.data.ARTCCs!.count).toEventually(equal(94))
            }
        }
    }
}
