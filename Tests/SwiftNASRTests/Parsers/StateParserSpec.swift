import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class StateParserSpec: QuickSpec {
    let fixturesURL = URL(fileURLWithPath: #file)
        .deletingLastPathComponent().deletingLastPathComponent()
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

            it("parses states") {
                try! NASR.parse(.states) { _ in false }
                expect(NASR.data.states!.count).to(equal(66))
            }
            
            it("returns a Publisher") {
                let publisher = NASR.parseStates()
                _ = publisher.sink(receiveCompletion: { _ in }, receiveValue: { states in
                    expect(states.count).to(equal(66))
                })
                expect(NASR.data.states!.count).toEventually(equal(66))
            }
        }
    }
}
