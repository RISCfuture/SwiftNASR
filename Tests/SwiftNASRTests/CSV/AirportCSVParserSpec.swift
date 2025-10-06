import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class CSVAirportParserSpec: AsyncSpec {
  override class func spec() {
    describe("CSVAirportParser") {
      let csvDirectory = URL(
        fileURLWithPath:
          "\(FileManager.default.currentDirectoryPath)/Tests/SwiftNASRTests/Resources/MockCSVDistribution"
      )

      context("when parsing CSV files") {
        it("parses airport base records") {
          let parser = CSVAirportParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          expect(parser.airports.count).to(beGreaterThan(0))

          if let firstAirport = parser.airports.values.first {
            expect(firstAirport.LID).notTo(beEmpty())
            expect(firstAirport.name).notTo(beEmpty())
            expect(firstAirport.city).notTo(beEmpty())
            expect(firstAirport.referencePoint.latitude).notTo(equal(0))
            expect(firstAirport.referencePoint.longitude).notTo(equal(0))
          }
        }

        it("correctly parses airport facility types") {
          let parser = CSVAirportParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // All parsed airports should have valid facility types
          for airport in parser.airports.values {
            expect(airport.facilityType).notTo(beNil())
          }
        }

        it("correctly parses airport status") {
          let parser = CSVAirportParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find an operational airport
          let operationalAirport = parser.airports.values.first { airport in
            airport.status == .operational
          }

          expect(operationalAirport).notTo(beNil())
        }

        it("correctly parses ICAO identifiers") {
          let parser = CSVAirportParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find an airport with ICAO ID
          let airportWithICAO = parser.airports.values.first { $0.ICAOIdentifier != nil }

          if let airport = airportWithICAO {
            expect(airport.ICAOIdentifier).notTo(beEmpty())
            // ICAO IDs are typically 4 characters
            expect(airport.ICAOIdentifier?.count).to(equal(4))
          }
        }

        it("correctly parses ownership type") {
          let parser = CSVAirportParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find airports with different ownership types
          var publicAirport: Airport?
          var privateAirport: Airport?
          for airport in parser.airports.values {
            if airport.ownership == Airport.Ownership.public && publicAirport == nil {
              publicAirport = airport
            } else if airport.ownership == Airport.Ownership.private && privateAirport == nil {
              privateAirport = airport
            }
            if publicAirport != nil && privateAirport != nil {
              break
            }
          }

          // At least one ownership type should be found
          expect(publicAirport ?? privateAirport).notTo(beNil())
        }

        it("correctly parses elevation") {
          let parser = CSVAirportParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find an airport with elevation
          let airportWithElev = parser.airports.values.first { $0.referencePoint.elevation != nil }

          if let airport = airportWithElev {
            expect(airport.referencePoint.elevation).notTo(beNil())
            // Elevation should be reasonable (between -500 and 20000 feet)
            expect(airport.referencePoint.elevation).to(beGreaterThan(-500))
            expect(airport.referencePoint.elevation).to(beLessThan(20000))
          }
        }
      }

      context("when CSV files are missing") {
        it("throws an error for missing files") {
          let parser = CSVAirportParser()
          parser.csvDirectory = URL(fileURLWithPath: "/tmp/nonexistent")

          await expect { try await parser.parse(data: Data()) }.to(throwError())
        }
      }
    }
  }
}
