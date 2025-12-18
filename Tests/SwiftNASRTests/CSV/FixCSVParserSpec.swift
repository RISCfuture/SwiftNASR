import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class CSVFixParserSpec: AsyncSpec {
  override class func spec() {
    describe("CSVFixParser") {
      let csvDirectory = Bundle.module.resourceURL!.appendingPathComponent(
        "MockCSVDistribution",
        isDirectory: true
      )

      context("when parsing CSV files") {
        it("parses fix base records") {
          let parser = CSVFixParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // CSV now has 5 fixes matching TXT: AARTA, ACMES, ACORI, ADOKY, ADONY
          expect(parser.fixes.count).to(equal(5))

          // Find AARTA fix
          let aarta = parser.fixes.values.first { $0.id == "AARTA" }
          expect(aarta).notTo(beNil())
          if let fix = aarta {
            expect(fix.ICAORegion).to(equal("K7"))
            expect(fix.position.latitudeArcsec).notTo(beNil())
            expect(fix.position.longitudeArcsec).notTo(beNil())
          }
        }

        it("parses navaid makeups from FIX_NAV.csv") {
          let parser = CSVFixParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // ACMES has navaid makeups
          let acmes = parser.fixes.values.first { $0.id == "ACMES" }
          expect(acmes).notTo(beNil())
          if let fix = acmes {
            expect(fix.navaidMakeups.count).to(beGreaterThan(0))

            let bvtMakeup = fix.navaidMakeups.first { $0.navaidId == "BVT" }
            expect(bvtMakeup).notTo(beNil())
            if let makeup = bvtMakeup {
              expect(makeup.navaidType).to(equal(NavaidFacilityType.VORTAC))
              expect(makeup.radialDeg).to(equal(270))
              expect(makeup.distanceNM).to(beCloseTo(15.5, within: 0.1))
            }
          }
        }

        it("parses chart types from FIX_CHRT.csv") {
          let parser = CSVFixParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // AARTA has IAP chart type
          let aarta = parser.fixes.values.first { $0.id == "AARTA" }
          expect(aarta).notTo(beNil())
          if let fix = aarta {
            expect(fix.chartTypes).to(contain("IAP"))
          }

          // ADONY has multiple chart types
          let adony = parser.fixes.values.first { $0.id == "ADONY" }
          expect(adony).notTo(beNil())
          if let fix = adony {
            expect(fix.chartTypes.count).to(beGreaterThanOrEqualTo(2))
            expect(fix.chartTypes).to(contain("STAR"))
            expect(fix.chartTypes).to(contain("SID"))
          }
        }

        it("correctly parses fix use codes") {
          let parser = CSVFixParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          let aarta = parser.fixes.values.first { $0.id == "AARTA" }
          expect(aarta?.use).to(equal(Fix.Use.waypoint))

          let adony = parser.fixes.values.first { $0.id == "ADONY" }
          expect(adony?.use).to(equal(Fix.Use.computerNavigationFix))
        }
      }

      context("when CSV files are missing") {
        it("throws an error for missing files") {
          let parser = CSVFixParser()
          parser.csvDirectory = URL(fileURLWithPath: "/tmp/nonexistent")

          await expect { try await parser.parse(data: Data()) }.to(throwError())
        }
      }
    }
  }
}
