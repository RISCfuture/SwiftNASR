import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class FSSParserSpec: QuickSpec {
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

            it("parses FSSes") {
                waitUntil { done in
                    try! nasr.parse(RecordType.flightServiceStations, errorHandler: {
                        fail(($0 as CustomStringConvertible).description)
                        done()
                        return false
                    }, completionHandler: { done() })
                }
                expect(nasr.data.FSSes!.count).to(equal(2))
                
                let FTW = nasr.data.FSSes!.first(where: { $0.ID == "FTW" })!
                expect(FTW.commFacilities.count).to(equal(20))
                expect(FTW.navaids.count).to(equal(79))
            }
            
            it("returns a Publisher") {
                let publisher = nasr.parseFSSesPublisher()
                _ = publisher.sink(receiveCompletion: { _ in }, receiveValue: { FSSes in
                    expect(FSSes.count).to(equal(2))
                })
                expect(nasr.data.FSSes!.count).toEventually(equal(2))
            }
        }
    }
}
