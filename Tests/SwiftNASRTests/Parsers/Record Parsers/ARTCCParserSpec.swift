import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class ARTCCParserSpec: QuickSpec {
    override func spec() {
        describe("parse") {
            let distURL = Bundle.module.resourceURL!.appendingPathComponent("MockDistribution", isDirectory: true)
            let nasr = NASR.fromLocalDirectory(distURL)

            beforeEach {
                waitUntil { done in
                    _ = nasr.load { result in
                        switch result {
                        case .failure(let error): fail((error as CustomStringConvertible).description)
                        default: break
                        }
                        done()
                    }
                }
            }

            it("parses centers, frequencies, and remarks") {
                waitUntil { done in
                    try! nasr.parse(RecordType.ARTCCFacilities, errorHandler: {
                        fail(($0 as CustomStringConvertible).description)
                        done()
                        return false
                    }, completionHandler: { done() })
                }
                expect(nasr.data.ARTCCs!.count).to(equal(94))
                
                let anchorage = nasr.data.ARTCCs!.first(where: { $0.ID == "ZAN" && $0.locationName == "ANCHORAGE" && $0.type == ARTCC.FacilityType.ARTCC })!
                expect(anchorage.remarks.general.count).to(equal(9))
                expect(anchorage.frequencies.count).to(equal(4))
                
                let dillingham = nasr.data.ARTCCs!.first(where: { $0.ID == "ZAN" && $0.locationName == "DILLINGHAM" && $0.type == ARTCC.FacilityType.RCAG })!
                expect(dillingham.frequencies[0].remarks.general.count).to(equal(1))
            }
            
            it("returns a Publisher") {
                let publisher = nasr.parseARTCCsPublisher()
                _ = publisher.sink(receiveCompletion: { _ in }, receiveValue: { ARTCCs in
                    expect(ARTCCs.count).to(equal(94))
                })
                expect(nasr.data.ARTCCs!.count).toEventually(equal(94))
            }
        }
    }
}
