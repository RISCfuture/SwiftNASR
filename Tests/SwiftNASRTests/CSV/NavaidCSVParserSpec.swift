import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class CSVNavaidParserSpec: AsyncSpec {
  override class func spec() {
    describe("CSVNavaidParser") {
      let csvDirectory = Bundle.module.resourceURL!.appendingPathComponent(
        "MockCSVDistribution",
        isDirectory: true
      )

      context("when parsing CSV files") {
        it("parses navaid base records") {
          let parser = CSVNavaidParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          expect(parser.navaids.count).to(beGreaterThan(0))

          if let firstNavaid = parser.navaids.values.first {
            expect(firstNavaid.id).notTo(beEmpty())
            expect(firstNavaid.name).notTo(beEmpty())
            expect(firstNavaid.city).notTo(beEmpty())
            expect(firstNavaid.position.latitudeArcsec).notTo(beNil())
            expect(firstNavaid.position.longitudeArcsec).notTo(beNil())
          }
        }

        it("parses navaid checkpoints") {
          let parser = CSVNavaidParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find a navaid with checkpoints
          let navaidWithCheckpoints = parser.navaids.values.first { !$0.checkpoints.isEmpty }

          if let navaid = navaidWithCheckpoints {
            expect(navaid.checkpoints.count).to(beGreaterThan(0))

            if let checkpoint = navaid.checkpoints.first {
              expect(checkpoint.bearing.value).to(beGreaterThan(0))
              expect(checkpoint.bearing.reference).to(equal(.magnetic))
              // Check appropriate description based on checkpoint type
              if checkpoint.airDescription != nil {
                expect(checkpoint.airDescription).notTo(beEmpty())
              } else if checkpoint.groundDescription != nil {
                expect(checkpoint.groundDescription).notTo(beEmpty())
              }
            }
          }
        }

        it("correctly parses magnetic variation") {
          let parser = CSVNavaidParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find a navaid with magnetic variation
          let navaidWithMagVar = parser.navaids.values.first { $0.magneticVariationDeg != nil }

          if let navaid = navaidWithMagVar {
            expect(navaid.magneticVariationDeg).notTo(beNil())
            // Magnetic variation should be reasonable (between -180 and 180)
            expect(navaid.magneticVariationDeg).to(beGreaterThan(-180))
            expect(navaid.magneticVariationDeg).to(beLessThan(180))
          }
        }

        it("correctly parses frequency for VOR/DME types") {
          let parser = CSVNavaidParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find a VOR or DME navaid
          let vorNavaid = parser.navaids.values.first { navaid in
            navaid.type == .VOR || navaid.type == .VORDME || navaid.type == .VORTAC
          }

          if let navaid = vorNavaid {
            expect(navaid.frequencyKHz).notTo(beNil())
            // VOR frequencies are typically between 108-118 MHz (108000-118000 kHz)
            if let freq = navaid.frequencyKHz {
              expect(freq).to(beGreaterThan(100000))
              expect(freq).to(beLessThan(120000))
            }
          }
        }
      }

      context("when CSV files are missing") {
        it("throws an error for missing files") {
          let parser = CSVNavaidParser()
          parser.csvDirectory = URL(fileURLWithPath: "/tmp/nonexistent")

          await expect { try await parser.parse(data: Data()) }.to(throwError())
        }
      }
    }
  }
}
