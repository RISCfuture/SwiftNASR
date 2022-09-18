import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class StateParserSpec: QuickSpec {
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

            it("parses states") {
                waitUntil { done in
                    try! nasr.parse(.states, errorHandler: {
                        fail(($0 as CustomStringConvertible).description)
                        done()
                        return false
                    }, completionHandler: { done() })
                }
                expect(nasr.data.states!.count).to(equal(66))
            }
            
            it("returns a Publisher") {
                let publisher = nasr.parseStatesPublisher()
                _ = publisher.sink(receiveCompletion: { _ in }, receiveValue: { states in
                    expect(states.count).to(equal(66))
                })
                expect(nasr.data.states!.count).toEventually(equal(66))
            }
        }
    }
}
