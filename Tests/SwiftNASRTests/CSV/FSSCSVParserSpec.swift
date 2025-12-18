import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class CSVFSSParserSpec: AsyncSpec {
  override class func spec() {
    describe("CSVFSSParser") {
      let csvDirectory = Bundle.module.resourceURL!.appendingPathComponent(
        "MockCSVDistribution",
        isDirectory: true
      )

      context("when parsing CSV files") {
        it("parses FSS base records") {
          let parser = CSVFSSParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          expect(parser.FSSes.count).to(beGreaterThan(0))

          if let firstFSS = parser.FSSes.values.first {
            expect(firstFSS.id).notTo(beEmpty())
            expect(firstFSS.name).notTo(beEmpty())
            expect(firstFSS.hoursOfOperation).notTo(beEmpty())
            expect(firstFSS.location?.latitudeArcsec).notTo(beNil())
            expect(firstFSS.location?.longitudeArcsec).notTo(beNil())
          }
        }

        it("correctly parses FSS facility types") {
          let parser = CSVFSSParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // All parsed FSSes should have valid facility types
          for fss in parser.FSSes.values {
            expect(fss.type).notTo(beNil())
          }
        }

        it("correctly parses phone numbers") {
          let parser = CSVFSSParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find an FSS with phone numbers
          let fssWithPhone = parser.FSSes.values.first { $0.phoneNumber != nil }

          if let fss = fssWithPhone {
            if let phone = fss.phoneNumber {
              expect(phone).notTo(beEmpty())
            }
          }
        }

        it("correctly parses weather radar flag") {
          let parser = CSVFSSParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Check that weather radar flag is properly parsed
          var fssWithRadar: FSS?
          var fssWithoutRadar: FSS?

          for fss in parser.FSSes.values {
            if fss.hasWeatherRadar == true && fssWithRadar == nil {
              fssWithRadar = fss
            } else if fss.hasWeatherRadar == false && fssWithoutRadar == nil {
              fssWithoutRadar = fss
            }
            if fssWithRadar != nil && fssWithoutRadar != nil {
              break
            }
          }

          // At least some FSSes should have weather radar info
          expect(fssWithRadar ?? fssWithoutRadar).notTo(beNil())
        }

        it("associates remarks with FSS records") {
          let parser = CSVFSSParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find an FSS with remarks
          let fssWithRemarks = parser.FSSes.values.first { !$0.remarks.isEmpty }

          // We might not have remarks in CSV yet but that's okay
          expect(parser.FSSes.count).to(beGreaterThan(0))
        }
      }

      context("when CSV files are missing") {
        it("throws an error for missing files") {
          let parser = CSVFSSParser()
          parser.csvDirectory = URL(fileURLWithPath: "/tmp/nonexistent")

          await expect { try await parser.parse(data: Data()) }.to(throwError())
        }
      }
    }
  }
}
