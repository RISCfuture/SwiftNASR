import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class FixParserSpec: AsyncSpec {
  override class func spec() {
    describe("parse") {
      let distURL = Bundle.module.resourceURL!.appendingPathComponent(
        "MockDistribution",
        isDirectory: true
      )
      let nasr = NASR.fromLocalDirectory(distURL)

      beforeEach {
        try await nasr.load()
      }

      it("parses fixes") {
        try await nasr.parse(RecordType.reportingPoints) { error in
          fail(error.localizedDescription)
          return false
        }

        guard let fixes = await nasr.data.fixes else {
          fail()
          return
        }
        // FIX.txt has 5 unique fixes: AARTA, ACMES, ACORI, ADOKY, ADONY
        expect(fixes.count).to(equal(5))

        // Verify AARTA fix
        guard let aarta = fixes.first(where: { $0.id == "AARTA" }) else {
          fail("AARTA fix not found")
          return
        }
        expect(aarta.stateName).to(equal("ALABAMA"))
        expect(aarta.ICAORegion).to(equal("K7"))
        // 34-36-21.290N = 34*3600 + 36*60 + 21.290 = 124581.29 arc-seconds
        expect(aarta.position.latitude).to(beCloseTo(124581.29, within: 0.01))
        // 087-16-24.750W = -(87*3600 + 16*60 + 24.750) = -314184.75 arc-seconds
        expect(aarta.position.longitude).to(beCloseTo(-314184.75, within: 0.01))
        expect(aarta.category).to(equal(Fix.Category.civil))
        expect(aarta.isPublished).to(beTrue())
        expect(aarta.use).to(equal(Fix.Use.waypoint))
        expect(aarta.chartTypes.count).to(equal(1))
        expect(aarta.chartTypes).to(contain("IAP"))

        // Verify ACMES fix with enroute high chart type
        guard let acmes = fixes.first(where: { $0.id == "ACMES" }) else {
          fail("ACMES fix not found")
          return
        }
        expect(acmes.chartTypes).to(contain("ENROUTE HIGH"))

        // Verify ACORI fix has multiple chart types
        guard let acori = fixes.first(where: { $0.id == "ACORI" }) else {
          fail("ACORI fix not found")
          return
        }
        expect(acori.chartTypes.count).to(equal(2))
        expect(acori.chartTypes).to(contain("CONTROLLER HIGH"))
        expect(acori.chartTypes).to(contain("ENROUTE HIGH"))

        // Verify ADONY has CNF use type
        guard let adony = fixes.first(where: { $0.id == "ADONY" }) else {
          fail("ADONY fix not found")
          return
        }
        expect(adony.use).to(equal(Fix.Use.computerNavigationFix))
      }
    }
  }
}
