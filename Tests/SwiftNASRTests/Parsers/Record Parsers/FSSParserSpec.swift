import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class FSSParserSpec: AsyncSpec {
    override class func spec() {
        describe("parse") {
            let distURL = Bundle.module.resourceURL!.appendingPathComponent("MockDistribution", isDirectory: true)
            let nasr = NASR.fromLocalDirectory(distURL)

            beforeEach {
                try await nasr.load()
            }

            it("parses FSSes") {
                try await nasr.parse(RecordType.flightServiceStations) { error in
                    fail(error.localizedDescription)
                    return false
                }

                guard let FSSes = await nasr.data.FSSes else { fail(); return }
                expect(FSSes.count).to(equal(2))

                guard let FTW = FSSes.first(where: { $0.ID == "FTW" }) else { fail(); return }
                expect(FTW.commFacilities.count).to(equal(20))
                expect(FTW.navaids.count).to(equal(79))
            }
        }
    }
}
