import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class StateParserSpec: QuickSpec {
    override class func spec() {
        describe("parse") {
            let distURL = Bundle.module.resourceURL!.appendingPathComponent("MockDistribution", isDirectory: true)
            let nasr = NASR.fromLocalDirectory(distURL)

            beforeEach {
                waitUntil { done in
                    nasr.load { result in
                        if case let .failure(error) = result {
                            fail((error as CustomStringConvertible).description)
                            return
                        }
                        done()
                    }
                }
            }

            it("parses states") {
                waitUntil { done in
                    try! nasr.parse(.states, errorHandler: {
                        print(($0 as CustomStringConvertible).description)
                        return false
                    }, completionHandler: { done() })
                }
                expect(nasr.data.states).notTo(beNil())
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
