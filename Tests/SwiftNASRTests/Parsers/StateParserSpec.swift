import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class StateParserSpec: AsyncSpec {
    override class func spec() {
        describe("parse") {
            let distURL = Bundle.module.resourceURL!.appendingPathComponent("MockDistribution", isDirectory: true)
            let nasr = NASR.fromLocalDirectory(distURL)
            
            beforeEach {
                try await nasr.load()
            }
            
            it("parses states") {
                try await nasr.parse(.states, errorHandler: {
                    fail($0.localizedDescription)
                    return false
                })
                
                guard let states = await nasr.data.states else { fail(); return }
                expect(states.count).to(equal(66))
            }
        }
    }
}
