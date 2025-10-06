import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class CSVARTCCParserSpec: AsyncSpec {
  override class func spec() {
    describe("CSVARTCCParser") {
      let csvDirectory = URL(
        fileURLWithPath:
          "\(FileManager.default.currentDirectoryPath)/Tests/SwiftNASRTests/Resources/MockCSVDistribution"
      )

      context("when parsing CSV files") {
        it("parses ARTCC base records from ATC files") {
          let parser = CSVARTCCParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          expect(parser.ARTCCs.count).to(beGreaterThan(0))

          if let firstARTCC = parser.ARTCCs.values.first {
            expect(firstARTCC.ID).notTo(beEmpty())
            expect(firstARTCC.name).notTo(beEmpty())
            expect(firstARTCC.locationName).notTo(beEmpty())
          }
        }

        it("correctly maps ATC facility types to ARTCC types") {
          let parser = CSVARTCCParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // All parsed ARTCCs should have valid facility types
          for artcc in parser.ARTCCs.values {
            expect(artcc.type).notTo(beNil())
            // Type should be one of the known ARTCC facility types
            let validTypes: [ARTCC.FacilityType] = [.ARTCC, .CERAP]
            expect(validTypes).to(contain(artcc.type))
          }
        }

        it("correctly parses ICAO identifiers") {
          let parser = CSVARTCCParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find an ARTCC with ICAO ID
          let artccWithICAO = parser.ARTCCs.values.first { $0.ICAOID != nil }

          if let artcc = artccWithICAO {
            expect(artcc.ICAOID).notTo(beEmpty())
            // ICAO IDs are typically 4 characters
            expect(artcc.ICAOID?.count).to(beGreaterThanOrEqualTo(3))
            expect(artcc.ICAOID?.count).to(beLessThanOrEqualTo(7))
          }
        }

        it("associates remarks with ARTCC records") {
          let parser = CSVARTCCParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find an ARTCC with remarks
          let artccWithRemarks = parser.ARTCCs.values.first { !$0.remarks.remarks.isEmpty }

          if let artcc = artccWithRemarks {
            expect(artcc.remarks.remarks.count).to(beGreaterThan(0))
          }
        }

        it("creates unique ARTCC keys") {
          let parser = CSVARTCCParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // All ARTCCs should have unique keys
          let uniqueIDs = Set(parser.ARTCCs.values.map(\.ID))
          expect(uniqueIDs.count).to(beGreaterThan(0))

          // Each ARTCC should have a unique combination of ID, location, and type
          for artcc in parser.ARTCCs.values {
            let key = ARTCCKey(center: artcc)
            expect(parser.ARTCCs[key]).notTo(beNil())
          }
        }
      }

      context("when CSV files are missing") {
        it("throws an error for missing files") {
          let parser = CSVARTCCParser()
          parser.csvDirectory = URL(fileURLWithPath: "/tmp/nonexistent")

          await expect { try await parser.parse(data: Data()) }.to(throwError())
        }
      }
    }
  }
}
