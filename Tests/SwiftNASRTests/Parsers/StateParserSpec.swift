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
            let nasr = NASR.fromLocalDirectory(distURL)

            beforeEach {
                let group = DispatchGroup()
                group.enter()
                nasr.load { _ in group.leave() }
                group.wait()
            }

            it("parses states") {
                try! nasr.parse(.states) { _ in false }
                expect(nasr.data.states!.count).to(equal(66))
            }
            
            it("returns a Publisher") {
                let publisher = nasr.parseStates()
                _ = publisher.sink(receiveCompletion: { _ in }, receiveValue: { states in
                    expect(states.count).to(equal(66))
                })
                expect(nasr.data.states!.count).toEventually(equal(66))
            }
        }
    }
}
