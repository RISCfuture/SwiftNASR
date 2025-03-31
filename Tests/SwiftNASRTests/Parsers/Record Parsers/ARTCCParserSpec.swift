import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class ARTCCParserSpec: AsyncSpec {
    override class func spec() {
        describe("parse") {
            let distURL = Bundle.module.resourceURL!.appendingPathComponent("MockDistribution", isDirectory: true)
            let nasr = NASR.fromLocalDirectory(distURL)

            beforeEach {
                try await nasr.load()
            }

            it("parses centers, frequencies, and remarks") {
                try await nasr.parse(.ARTCCFacilities, errorHandler: { error in
                    fail(error.localizedDescription)
                    return false
                })

                guard let ARTCCs = await nasr.data.ARTCCs else { fail(); return }
                expect(ARTCCs.count).to(equal(94))

                guard let anchorage = ARTCCs.first(where: { $0.ID == "ZAN" && $0.locationName == "ANCHORAGE" && $0.type == ARTCC.FacilityType.ARTCC }) else { fail(); return }
                expect(anchorage.remarks.general.count).to(equal(9))
                expect(anchorage.frequencies.count).to(equal(4))

                guard let dillingham = ARTCCs.first(where: { $0.ID == "ZAN" && $0.locationName == "DILLINGHAM" && $0.type == ARTCC.FacilityType.RCAG }) else { fail(); return }
                expect(dillingham.frequencies[0].remarks.general.count).to(equal(1))
            }
        }
    }
}
