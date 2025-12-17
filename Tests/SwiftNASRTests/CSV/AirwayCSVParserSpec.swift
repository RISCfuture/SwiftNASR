import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class CSVAirwayParserSpec: AsyncSpec {
  override class func spec() {
    describe("CSVAirwayParser") {
      let csvDirectory = Bundle.module.resourceURL!.appendingPathComponent(
        "MockCSVDistribution",
        isDirectory: true
      )

      context("when parsing CSV files") {
        it("parses airway base records") {
          let parser = CSVAirwayParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          expect(parser.airways.count).to(beGreaterThan(0))

          // Find A16 airway (Federal - A16 is Amber colored, not Alaska)
          let a16Key = AirwayKey(designation: "A16", type: .federal)
          let a16 = parser.airways[a16Key]
          expect(a16).notTo(beNil())
          if let airway = a16 {
            expect(airway.type).to(equal(Airway.AirwayType.federal))
            expect(airway.remarks.count).to(beGreaterThan(0))
          }
        }

        it("parses airway segments from AWY_SEG_ALT.csv") {
          let parser = CSVAirwayParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // B9 has multiple segments
          let b9Key = AirwayKey(designation: "B9", type: .federal)
          let b9 = parser.airways[b9Key]
          expect(b9).notTo(beNil())
        }

        it("assembles airways with segments correctly") {
          let parser = CSVAirwayParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          let data = NASRData()
          await parser.finish(data: data)

          guard let airways = await data.airways else {
            fail("Airways not set on data")
            return
          }

          // Find A16 with assembled segments (Federal - A16 is Amber colored, not Alaska)
          let a16 = airways.first { $0.designation == "A16" && $0.type == .federal }
          expect(a16).notTo(beNil())
          if let airway = a16 {
            expect(airway.segments.count).to(equal(2))

            // Verify first segment
            if let firstSegment = airway.segments.first {
              expect(firstSegment.sequenceNumber).to(equal(10))
              expect(firstSegment.point.name).to(equal("AP"))
              expect(firstSegment.altitudes.MEA).to(equal(3000))
              expect(firstSegment.distanceToNext).to(beCloseTo(22.7, within: 0.1))
            }
          }

          // Find B9
          let b9 = airways.first { $0.designation == "B9" && $0.type == .federal }
          expect(b9).notTo(beNil())
          if let airway = b9 {
            expect(airway.segments.count).to(equal(2))

            if let firstSegment = airway.segments.first {
              expect(firstSegment.point.name).to(equal("DEEDS"))
              expect(firstSegment.point.pointType).to(equal(.reportingPoint))
              expect(firstSegment.distanceToNext).to(beCloseTo(76.1, within: 0.1))
            }
          }
        }

        it("parses altitude data correctly") {
          let parser = CSVAirwayParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          let data = NASRData()
          await parser.finish(data: data)

          guard let airways = await data.airways else {
            fail("Airways not set on data")
            return
          }

          let b9 = airways.first { $0.designation == "B9" }
          expect(b9).notTo(beNil())
          if let airway = b9 {
            if let firstSegment = airway.segments.first {
              expect(firstSegment.altitudes.MEA).to(equal(2000))
            }
          }
        }

        it("parses changeover points when present") {
          let parser = CSVAirwayParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          let data = NASRData()
          await parser.finish(data: data)

          guard let airways = await data.airways else {
            fail("Airways not set on data")
            return
          }

          let a16 = airways.first { $0.designation == "A16" && $0.type == .federal }
          expect(a16).notTo(beNil())
          if let airway = a16 {
            if let firstSegment = airway.segments.first {
              expect(firstSegment.changeoverPoint).notTo(beNil())
              expect(firstSegment.changeoverPoint?.navaidName).to(equal("WHITE ROCK"))
              expect(firstSegment.changeoverPoint?.distance).to(equal(15))
            }
          }
        }
      }

      context("when CSV files are missing") {
        it("throws an error for missing files") {
          let parser = CSVAirwayParser()
          parser.csvDirectory = URL(fileURLWithPath: "/tmp/nonexistent")

          await expect { try await parser.parse(data: Data()) }.to(throwError())
        }
      }
    }
  }
}
