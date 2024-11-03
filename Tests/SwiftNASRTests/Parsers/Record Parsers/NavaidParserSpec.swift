import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class NavaidParserSpec: AsyncSpec {
    override class func spec() {
        describe("parse") {
            let distURL = Bundle.module.resourceURL!.appendingPathComponent("MockDistribution", isDirectory: true)
            let nasr = NASR.fromLocalDirectory(distURL)
            
            beforeEach {
                try await nasr.load()
            }
            
            it("parses navaids") {
                try await nasr.parse(RecordType.navaids, errorHandler: {
                    fail($0.localizedDescription)
                    return false
                })

                guard let navaids = await nasr.data.navaids else { fail(); return }
                expect(navaids.count).to(equal(2))
                
                guard let AST = navaids.first(where: { $0.ID == "AST" && $0.isVOR }) else { fail(); return }
                expect(AST.position.elevation).to(equal(10.6))
                expect(AST.remarks.count).to(equal(2))
                expect(AST.associatedFixNames.count).to(equal(21))
                expect(AST.associatedHoldingPatterns.count).to(equal(1))
                expect(AST.fanMarkers.count).to(equal(1))
                expect(AST.checkpoints.count).to(equal(1))
            }
        }
    }
}
