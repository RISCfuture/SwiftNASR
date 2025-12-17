import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class LocationIdentifierParserSpec: AsyncSpec {
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

      it("parses location identifiers") {
        try await nasr.parse(RecordType.locationIdentifiers) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let identifiers = await nasr.data.locationIdentifiers else {
          fail("locationIdentifiers is nil")
          return
        }

        expect(identifiers.count).to(equal(10))
      }

      it("parses group code") {
        try await nasr.parse(RecordType.locationIdentifiers) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let identifiers = await nasr.data.locationIdentifiers else {
          fail("locationIdentifiers is nil")
          return
        }

        let id = identifiers.first { $0.identifier == "A05" }
        expect(id?.groupCode).to(equal(.usa))
      }

      it("parses basic location information") {
        try await nasr.parse(RecordType.locationIdentifiers) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let identifiers = await nasr.data.locationIdentifiers else {
          fail("locationIdentifiers is nil")
          return
        }

        let id = identifiers.first { $0.identifier == "A05" }
        expect(id?.FAARegion).to(equal("ANM"))
        expect(id?.stateCode).to(equal("ID"))
        expect(id?.city).to(equal("DIXIE"))
      }

      it("parses controlling ARTCC") {
        try await nasr.parse(RecordType.locationIdentifiers) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let identifiers = await nasr.data.locationIdentifiers else {
          fail("locationIdentifiers is nil")
          return
        }

        let id = identifiers.first { $0.identifier == "A05" }
        expect(id?.controllingARTCC).to(equal("ZSE"))
        expect(id?.controllingARTCCComputerId).to(equal("ZCS"))
      }

      it("parses landing facility information") {
        try await nasr.parse(RecordType.locationIdentifiers) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let identifiers = await nasr.data.locationIdentifiers else {
          fail("locationIdentifiers is nil")
          return
        }

        let id = identifiers.first { $0.identifier == "A05" }
        expect(id?.landingFacilityName).to(equal("DIXIE USFS"))
        expect(id?.landingFacilityType).to(equal(.airport))
        expect(id?.landingFacilityFSS).to(equal("BOI"))
      }

      it("parses seaplane base facility type") {
        try await nasr.parse(RecordType.locationIdentifiers) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let identifiers = await nasr.data.locationIdentifiers else {
          fail("locationIdentifiers is nil")
          return
        }

        let id = identifiers.first { $0.identifier == "A11" }
        expect(id?.landingFacilityType).to(equal(.seaplaneBase))
        expect(id?.landingFacilityName).to(equal("CAMPBELL LAKE SPB"))
      }

      it("parses weather station (other facility)") {
        try await nasr.parse(RecordType.locationIdentifiers) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let identifiers = await nasr.data.locationIdentifiers else {
          fail("locationIdentifiers is nil")
          return
        }

        let id = identifiers.first { $0.identifier == "A19" }
        expect(id?.otherFacilityType).to(equal(.weatherStation))
        expect(id?.otherFacilityName).to(equal("MARS"))
        // No landing facility for this identifier
        expect(id?.landingFacilityName).to(beNil())
      }

      it("parses effective date") {
        try await nasr.parse(RecordType.locationIdentifiers) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let identifiers = await nasr.data.locationIdentifiers else {
          fail("locationIdentifiers is nil")
          return
        }

        let id = identifiers.first { $0.identifier == "A05" }
        expect(id?.effectiveDate).to(equal(DateComponents(year: 2021, month: 12, day: 30)))
      }

      it("parses Alaska region") {
        try await nasr.parse(RecordType.locationIdentifiers) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let identifiers = await nasr.data.locationIdentifiers else {
          fail("locationIdentifiers is nil")
          return
        }

        let id = identifiers.first { $0.identifier == "A11" }
        expect(id?.FAARegion).to(equal("AAL"))
        expect(id?.stateCode).to(equal("AK"))
        expect(id?.city).to(equal("ANCHORAGE"))
      }

      it("parses identifiers without ARTCC") {
        try await nasr.parse(RecordType.locationIdentifiers) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let identifiers = await nasr.data.locationIdentifiers else {
          fail("locationIdentifiers is nil")
          return
        }

        // Weather stations may not have controlling ARTCC
        let id = identifiers.first { $0.identifier == "A19" }
        expect(id?.controllingARTCC).to(beNil())
        expect(id?.controllingARTCCComputerId).to(beNil())
      }

      it("parses other facility with description") {
        try await nasr.parse(RecordType.locationIdentifiers) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let identifiers = await nasr.data.locationIdentifiers else {
          fail("locationIdentifiers is nil")
          return
        }

        let id = identifiers.first { $0.identifier == "A21" }
        expect(id?.otherFacilityType).to(equal(.weatherStation))
        expect(id?.otherFacilityName).to(contain("PORTAGE VISITOR CENTER"))
      }
    }
  }
}
