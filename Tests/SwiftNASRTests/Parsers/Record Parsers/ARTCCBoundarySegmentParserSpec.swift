import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class ARTCCBoundarySegmentParserSpec: AsyncSpec {
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

      it("parses ARTCC boundary segments") {
        try await nasr.parse(RecordType.ARTCCBoundarySegments) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let segments = await nasr.data.ARTCCBoundarySegments else {
          fail("ARTCCBoundarySegments is nil")
          return
        }

        expect(segments.count).to(equal(8))
      }

      it("parses record identifier correctly") {
        try await nasr.parse(RecordType.ARTCCBoundarySegments) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let segments = await nasr.data.ARTCCBoundarySegments else {
          fail("ARTCCBoundarySegments is nil")
          return
        }

        let segment = segments.first { $0.ARTCCIdentifier == "ZLA" && $0.altitudeStructure == .low }
        expect(segment).toNot(beNil())
        expect(segment?.ARTCCIdentifier).to(equal("ZLA"))
        expect(segment?.pointDesignator).to(equal("00001"))
      }

      it("parses center name and altitude structure") {
        try await nasr.parse(RecordType.ARTCCBoundarySegments) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let segments = await nasr.data.ARTCCBoundarySegments else {
          fail("ARTCCBoundarySegments is nil")
          return
        }

        let segment = segments.first { $0.ARTCCIdentifier == "ZLA" && $0.altitudeStructure == .low }
        expect(segment?.centerName).to(equal("LOS ANGELES CENTER"))
        expect(segment?.altitudeStructureName).to(equal("LOW"))
      }

      it("parses coordinates correctly") {
        try await nasr.parse(RecordType.ARTCCBoundarySegments) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let segments = await nasr.data.ARTCCBoundarySegments else {
          fail("ARTCCBoundarySegments is nil")
          return
        }

        // 34°00'00"N = 34*3600 = 122400 arc-seconds
        // 117°30'00"W = -(117*3600 + 30*60) = -423000 arc-seconds
        let segment = segments.first { $0.ARTCCIdentifier == "ZLA" && $0.altitudeStructure == .low }
        expect(segment?.position.latitude).to(beCloseTo(122400, within: 100))
        expect(segment?.position.longitude).to(beCloseTo(-423000, within: 100))
      }

      it("parses boundary description") {
        try await nasr.parse(RecordType.ARTCCBoundarySegments) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let segments = await nasr.data.ARTCCBoundarySegments else {
          fail("ARTCCBoundarySegments is nil")
          return
        }

        let segment = segments.first { $0.ARTCCIdentifier == "ZLA" && $0.altitudeStructure == .low }
        expect(segment?.boundaryDescription).to(contain("CALIFORNIA/NEVADA"))
      }

      it("parses sequence number") {
        try await nasr.parse(RecordType.ARTCCBoundarySegments) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let segments = await nasr.data.ARTCCBoundarySegments else {
          fail("ARTCCBoundarySegments is nil")
          return
        }

        let segment = segments.first { $0.ARTCCIdentifier == "ZLA" && $0.altitudeStructure == .low }
        expect(segment?.sequenceNumber).to(equal(1))
      }

      it("parses high altitude structure") {
        try await nasr.parse(RecordType.ARTCCBoundarySegments) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let segments = await nasr.data.ARTCCBoundarySegments else {
          fail("ARTCCBoundarySegments is nil")
          return
        }

        let highSegments = segments.filter {
          $0.ARTCCIdentifier == "ZLA" && $0.altitudeStructure == .high
        }
        expect(highSegments.count).to(equal(2))
        expect(highSegments.first?.altitudeStructureName).to(equal("HIGH"))
      }

      it("parses multiple ARTCCs") {
        try await nasr.parse(RecordType.ARTCCBoundarySegments) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let segments = await nasr.data.ARTCCBoundarySegments else {
          fail("ARTCCBoundarySegments is nil")
          return
        }

        let znySegments = segments.filter { $0.ARTCCIdentifier == "ZNY" }
        expect(znySegments.count).to(equal(3))
        expect(znySegments.first?.centerName).to(equal("NEW YORK CENTER"))
      }

      it("parses NAS description only flag") {
        try await nasr.parse(RecordType.ARTCCBoundarySegments) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let segments = await nasr.data.ARTCCBoundarySegments else {
          fail("ARTCCBoundarySegments is nil")
          return
        }

        let nasOnlySegment = segments.first { $0.NASDescriptionOnly == true }
        expect(nasOnlySegment).toNot(beNil())
        expect(nasOnlySegment?.ARTCCIdentifier).to(equal("ZNY"))
        expect(nasOnlySegment?.boundaryDescription).to(contain("NAS DESCRIPTION"))

        // Check that most segments are NOT NAS only
        let normalSegments = segments.filter { $0.NASDescriptionOnly != true }
        expect(normalSegments.count).to(equal(7))
      }

      it("detects point of beginning in boundary description") {
        try await nasr.parse(RecordType.ARTCCBoundarySegments) { error in
          fail(error.localizedDescription)
          return false
        }
        guard let segments = await nasr.data.ARTCCBoundarySegments else {
          fail("ARTCCBoundarySegments is nil")
          return
        }

        let closingSegments = segments.filter {
          $0.boundaryDescription.contains("POINT OF BEGINNING")
        }
        expect(closingSegments.count).to(beGreaterThan(0))
      }
    }
  }
}
