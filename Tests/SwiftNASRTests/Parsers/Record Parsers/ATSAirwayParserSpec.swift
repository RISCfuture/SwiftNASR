import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class ATSAirwayParserSpec: AsyncSpec {
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

      it("parses ATS airways") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        expect(airways.count).to(equal(3))
      }

      it("parses Atlantic route designation") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "A301" }
        expect(airway).toNot(beNil())
        expect(airway?.designation).to(equal(.atlantic))
        expect(airway?.id).to(equal("ATA301"))
      }

      it("parses Bahama route designation") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "B230" }
        expect(airway).toNot(beNil())
        expect(airway?.designation).to(equal(.bahama))
        expect(airway?.isRNAV).to(beTrue())
      }

      it("parses Pacific route with Hawaii type") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "P3" }
        expect(airway).toNot(beNil())
        expect(airway?.designation).to(equal(.pacific))
        expect(airway?.airwayType).to(equal(.hawaii))
      }

      it("parses route points") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "A301" }
        expect(airway?.routePoints.count).to(equal(5))
      }

      it("parses route point coordinates") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "A301" }
        // 24°00'00"N ≈ 86400 arc-seconds, 79°04'12"W ≈ -284652 arc-seconds
        let firstPoint = airway?.routePoints.first { $0.sequenceNumber == 10 }
        expect(firstPoint?.pointName).to(equal("URSUS"))
        expect(firstPoint?.position?.latitude).to(beCloseTo(86400, within: 100))
        expect(firstPoint?.position?.longitude).to(beCloseTo(-284651, within: 100))
      }

      it("parses MEA data") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "A301" }
        let point = airway?.routePoints.first { $0.sequenceNumber == 10 }
        expect(point?.minimumEnrouteAltitude).to(equal(10000))
        expect(point?.minimumReceptionAltitude).to(equal(16000))
      }

      it("parses changeover point data") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "A301" }
        let point = airway?.routePoints.first { $0.sequenceNumber == 10 }
        expect(point?.changeoverNavaidName).to(equal("ZOLLA VOR"))
        expect(point?.changeoverNavaidType).to(equal(.VORDME))
      }

      it("parses point remarks") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "A301" }
        let point = airway?.routePoints.first { $0.sequenceNumber == 10 }
        expect(point?.remarks.count).to(equal(1))
        expect(point?.remarks.first).to(contain("MEA 10000"))
      }

      it("parses changeover exceptions") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "A301" }
        let point = airway?.routePoints.first { $0.sequenceNumber == 10 }
        expect(point?.changeoverExceptions.count).to(equal(1))
        expect(point?.changeoverExceptions.first).to(contain("Changeover at 50 DME"))
      }

      it("parses route remarks") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "A301" }
        expect(airway?.routeRemarks.count).to(equal(1))
        expect(airway?.routeRemarks.first).to(contain("Atlantic route A301"))
      }

      it("parses effective date") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "A301" }
        expect(airway?.effectiveDate).to(equal(DateComponents(year: 2021, month: 12, day: 2)))
      }

      it("parses ARTCC identifier") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "A301" }
        let point = airway?.routePoints.first { $0.sequenceNumber == 10 }
        expect(point?.ARTCCIdentifier).to(equal("ZMA"))
      }

      it("parses point type") {
        try await nasr.parse(RecordType.ATSAirways) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let airways = await nasr.data.atsAirways else {
          fail("atsAirways is nil")
          return
        }

        let airway = airways.first { $0.airwayIdentifier == "A301" }
        let fixPoint = airway?.routePoints.first { $0.sequenceNumber == 10 }
        expect(fixPoint?.pointType).to(equal(.reportingPoint))
        expect(fixPoint?.isNamedFix).to(beTrue())

        let VORTACPoint = airway?.routePoints.first { $0.sequenceNumber == 50 }
        expect(VORTACPoint?.pointType).to(equal(.VORTAC))
      }
    }
  }
}
