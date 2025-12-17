import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class CSVTerminalCommFacilityParserSpec: AsyncSpec {
  override class func spec() {
    describe("CSVTerminalCommFacilityParser") {
      let csvDirectory = Bundle.module.resourceURL!.appendingPathComponent(
        "MockCSVDistribution",
        isDirectory: true
      )

      context("when parsing CSV files") {
        it("parses terminal comm facility base records") {
          let parser = CSVTerminalCommFacilityParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // The mock ATC_BASE.csv has multiple facilities
          expect(parser.facilities.count).to(beGreaterThan(0))

          // Find ABE facility (ATCT-TRACON)
          let abe = parser.facilities.values.first { $0.facilityId == "ABE" }
          expect(abe).notTo(beNil())
          if let facility = abe {
            expect(facility.stateCode).to(equal("PA"))
            expect(facility.city).to(equal("ALLENTOWN"))
            expect(facility.airportName).to(equal("LEHIGH VALLEY INTL"))
            expect(facility.regionCode).to(equal("AEA"))
            expect(facility.facilityType).to(equal(TerminalCommFacility.FacilityType.ATCTTRACON))
            expect(facility.towerOperator).to(equal("F"))
            expect(facility.towerRadioCall).to(equal("ALLENTOWN"))
            expect(facility.towerHours).to(equal("24"))
            expect(facility.primaryApproachRadioCall).to(equal("ALLENTOWN"))
          }
        }

        it("parses NON-ATCT facilities") {
          let parser = CSVTerminalCommFacilityParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find 00R facility (NON-ATCT)
          let facility00R = parser.facilities.values.first { $0.facilityId == "00R" }
          expect(facility00R).notTo(beNil())
          if let facility = facility00R {
            expect(facility.stateCode).to(equal("TX"))
            expect(facility.city).to(equal("LIVINGSTON"))
            expect(facility.airportName).to(equal("LIVINGSTON MUNI"))
            expect(facility.facilityType).to(equal(TerminalCommFacility.FacilityType.nonATCT))
          }
        }

        it("parses TRACON facilities") {
          let parser = CSVTerminalCommFacilityParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // Find A11 facility (TRACON)
          let a11 = parser.facilities.values.first { $0.facilityId == "A11" }
          expect(a11).notTo(beNil())
          if let facility = a11 {
            expect(facility.stateCode).to(equal("AK"))
            expect(facility.city).to(equal("ANCHORAGE"))
            expect(facility.airportName).to(equal("ANCHORAGE APPROACH CONTROL"))
            expect(facility.facilityType).to(equal(TerminalCommFacility.FacilityType.TRACON))
          }
        }

        it("parses services from ATC_SVC.csv") {
          let parser = CSVTerminalCommFacilityParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // ABE should have services
          let abe = parser.facilities.values.first { $0.facilityId == "ABE" }
          expect(abe?.masterAirportServices).notTo(beNil())
          if let services = abe?.masterAirportServices {
            expect(services).to(contain("APPROACH/DEPARTURE CONTROL"))
          }
        }

        it("parses ATIS data from ATC_ATIS.csv") {
          let parser = CSVTerminalCommFacilityParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // ABE should have ATIS info
          let abe = parser.facilities.values.first { $0.facilityId == "ABE" }
          expect(abe?.ATISInfo.count).to(equal(2))

          // Check first ATIS entry
          let arrivalATIS = abe?.ATISInfo.first { $0.serialNumber == 1 }
          expect(arrivalATIS).notTo(beNil())
          if let atis = arrivalATIS {
            expect(atis.description).to(equal("ARRIVAL"))
            expect(atis.hours).to(equal("24"))
            expect(atis.phoneNumber).to(equal("610-555-1234"))
          }

          // Check second ATIS entry
          let departureATIS = abe?.ATISInfo.first { $0.serialNumber == 2 }
          expect(departureATIS).notTo(beNil())
          if let atis = departureATIS {
            expect(atis.description).to(equal("DEPARTURE"))
            expect(atis.hours).to(equal("24"))
          }
        }

        it("parses remarks from ATC_RMK.csv") {
          let parser = CSVTerminalCommFacilityParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          // 00R should have remarks
          let facility00R = parser.facilities.values.first { $0.facilityId == "00R" }
          expect(facility00R?.remarks.count).to(beGreaterThan(0))
          if let remark = facility00R?.remarks.first {
            expect(remark).to(contain("APCH/DEP CTL SVC PRVDD BY HOUSTON ARTCC"))
          }
        }
      }

      context("when CSV files are missing") {
        it("throws an error for missing files") {
          let parser = CSVTerminalCommFacilityParser()
          parser.csvDirectory = URL(fileURLWithPath: "/tmp/nonexistent")

          await expect { try await parser.parse(data: Data()) }.to(throwError())
        }
      }
    }
  }
}
