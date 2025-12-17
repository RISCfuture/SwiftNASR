import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class CSVILSParserSpec: AsyncSpec {
  override class func spec() {
    describe("CSVILSParser") {
      let csvDirectory = Bundle.module.resourceURL!.appendingPathComponent(
        "MockCSVDistribution",
        isDirectory: true
      )

      context("when parsing CSV files") {
        it("parses ILS base records") {
          let parser = CSVILSParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          expect(parser.ILSFacilities.count).to(equal(2))

          // Find ANB ILS
          let anb = parser.ILSFacilities.values.first { $0.ILSId == "I-ANB" }
          expect(anb).notTo(beNil())
          if let ils = anb {
            expect(ils.airportId).to(equal("ANB"))
            expect(ils.city).to(equal("ANNISTON"))
            expect(ils.stateCode).to(equal("AL"))
            expect(ils.stateName).to(equal("ALABAMA"))
            expect(ils.regionCode).to(equal("ASO"))
            expect(ils.runwayLength).to(equal(7000))
            expect(ils.runwayWidth).to(equal(150))
            expect(ils.category).to(equal(ILS.Category.I))
            expect(ils.approachBearing?.value).to(beCloseTo(52.45, within: 0.01))
            expect(ils.approachBearing?.reference).to(equal(.magnetic))
          }
        }

        it("parses localizer data from ILS_BASE.csv") {
          let parser = CSVILSParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          let anb = parser.ILSFacilities.values.first { $0.ILSId == "I-ANB" }
          expect(anb?.localizer).notTo(beNil())
          if let localizer = anb?.localizer {
            expect(localizer.status).to(equal(OperationalStatus.operationalRestricted))
            expect(localizer.frequency).to(equal(111500))
            expect(localizer.position?.elevation).to(beCloseTo(612.1, within: 0.1))
          }
        }

        it("parses glide slope data from ILS_GS.csv") {
          let parser = CSVILSParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          let anb = parser.ILSFacilities.values.first { $0.ILSId == "I-ANB" }
          expect(anb?.glideSlope).notTo(beNil())
          if let glideSlope = anb?.glideSlope {
            expect(glideSlope.status).to(equal(OperationalStatus.operationalIFR))
            expect(glideSlope.glideSlopeType).to(equal(ILS.GlideSlope.GlidePathType.glideSlope))
            expect(glideSlope.angle).to(beCloseTo(3.0, within: 0.01))
            expect(glideSlope.frequency).to(equal(332900))
            expect(glideSlope.position?.elevation).to(beCloseTo(590.8, within: 0.1))
          }

          // Check AUO glide slope
          let auo = parser.ILSFacilities.values.first { $0.ILSId == "I-AUO" }
          expect(auo?.glideSlope).notTo(beNil())
          expect(auo?.glideSlope?.angle).to(beCloseTo(3.0, within: 0.01))
          expect(auo?.glideSlope?.frequency).to(equal(334400))
        }

        it("parses marker beacons from ILS_MKR.csv") {
          let parser = CSVILSParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          let anb = parser.ILSFacilities.values.first { $0.ILSId == "I-ANB" }
          expect(anb?.markers.count).to(equal(2))

          // Check outer marker
          let outerMarker = anb?.markers.first { $0.markerType == .outer }
          expect(outerMarker).notTo(beNil())
          if let marker = outerMarker {
            expect(marker.status).to(equal(OperationalStatus.operationalIFR))
            expect(marker.facilityType).to(equal(ILS.MarkerBeacon.MarkerFacilityType.markerNDB))
            expect(marker.locationId).to(equal("AN"))
            expect(marker.name).to(equal("BOGGA"))
            expect(marker.frequency).to(equal(211))
            expect(marker.collocatedNavaid).to(equal("AN*NDB"))
          }

          // Check middle marker (decommissioned)
          let middleMarker = anb?.markers.first { $0.markerType == .middle }
          expect(middleMarker).notTo(beNil())
          if let marker = middleMarker {
            expect(marker.status).to(equal(OperationalStatus.decommissioned))
            expect(marker.facilityType).to(equal(ILS.MarkerBeacon.MarkerFacilityType.marker))
          }
        }

        it("parses remarks from ILS_RMK.csv") {
          let parser = CSVILSParser()
          parser.csvDirectory = csvDirectory

          try await parser.parse(data: Data())

          let anb = parser.ILSFacilities.values.first { $0.ILSId == "I-ANB" }
          expect(anb?.remarks.count).to(equal(2))
          expect(anb?.remarks).to(contain("ILS CLASSIFICATION CODE IA"))
          expect(anb?.remarks).to(contain("LOC UNUSBL WI 0.6 NM; BYD 16 DEGS RIGHT OF CRS."))
        }
      }

      context("when CSV files are missing") {
        it("throws an error for missing files") {
          let parser = CSVILSParser()
          parser.csvDirectory = URL(fileURLWithPath: "/tmp/nonexistent")

          await expect { try await parser.parse(data: Data()) }.to(throwError())
        }
      }
    }
  }
}
