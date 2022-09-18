import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class NavaidParserSpec: QuickSpec {
    override func spec() {
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
            
            it("parses navaids") {
                waitUntil { done in
                    try! nasr.parse(RecordType.navaids, errorHandler: {
                        print(($0 as CustomStringConvertible).description)
                        return false
                    }, completionHandler: { done() })
                }
                
                expect(nasr.data.navaids).notTo(beNil())
                expect(nasr.data.navaids!.count).to(equal(2))
                
                let AST = nasr.data.navaids!.first(where: { $0.ID == "AST" && $0.isVOR })!
                expect(AST.position.elevation).to(equal(10.6))
                expect(AST.remarks.count).to(equal(2))
                expect(AST.associatedFixNames.count).to(equal(21))
                expect(AST.associatedHoldingPatterns.count).to(equal(1))
                expect(AST.fanMarkers.count).to(equal(1))
                expect(AST.checkpoints.count).to(equal(1))
            }
            
            it("returns a Publisher") {
                let publisher = nasr.parseNavaidsPublisher()
                _ = publisher.sink(receiveCompletion: { _ in }, receiveValue: { navaids in
                    expect(navaids.count).to(equal(2))
                })
                expect(nasr.data.navaids!.count).toEventually(equal(2))
            }
        }
    }
}
