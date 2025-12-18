import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class MockParser: LayoutDataParser {
  static let type = RecordType.airports
  var formats = [NASRTable]()

  func parse(data _: Data) throws {
    // do nothing
  }

  func finish(data _: NASRData) {
    // do nothing
  }
}

class ParserSpec: AsyncSpec {
  override class func spec() {
    describe("prepare") {
      it("parses all record formats from layout file") {
        let distURL = Bundle.module.resourceURL!.appendingPathComponent(
          "MockDistribution",
          isDirectory: true
        )
        let distribution = DirectoryDistribution(location: distURL)
        let parser = MockParser()

        try await parser.prepare(distribution: distribution)

        // APT layout file defines 5 record formats: APT, ATT, RWY, ARS, RMK
        expect(parser.formats.count).to(equal(5))
      }

      it("calculates correct 0-indexed field ranges from 1-indexed positions") {
        let distURL = Bundle.module.resourceURL!.appendingPathComponent(
          "MockDistribution",
          isDirectory: true
        )
        let distribution = DirectoryDistribution(location: distURL)
        let parser = MockParser()

        try await parser.prepare(distribution: distribution)

        let firstFormat = parser.formats[0]

        // First field: L AN 0003 00001 -> range 0..<3
        expect(firstFormat.fields[0].range).to(equal(0..<3))

        // Second field: L AN 0011 00004 -> range 3..<14
        expect(firstFormat.fields[1].range).to(equal(3..<14))

        // Third field: L AN 0013 00015 -> range 14..<27
        expect(firstFormat.fields[2].range).to(equal(14..<27))
      }

      it("correctly parses field identifier types") {
        let distURL = Bundle.module.resourceURL!.appendingPathComponent(
          "MockDistribution",
          isDirectory: true
        )
        let distribution = DirectoryDistribution(location: distURL)
        let parser = MockParser()

        try await parser.prepare(distribution: distribution)

        let firstFormat = parser.formats[0]

        // First field has N/A identifier -> .none
        expect(firstFormat.fields[0].identifier).to(equal(NASRTableField.Identifier.none))

        // Second field has DLID identifier -> .databaseLocatorID
        expect(firstFormat.fields[1].identifier).to(equal(.databaseLocatorID))

        // Look for a numbered field (e.g., E7, A1, etc.)
        let numberedField = firstFormat.fields.first {
          if case .number = $0.identifier { return true }
          return false
        }
        expect(numberedField).toNot(beNil())
      }

      it("throws badData if an L entry is invalid") {
        let distURL = Bundle.module.resourceURL!.appendingPathComponent(
          "FailingMockDistribution",
          isDirectory: true
        )
        let distribution = DirectoryDistribution(location: distURL)
        let parser = MockParser()

        await expect {
          try await parser.prepare(distribution: distribution)
        }.to(throwError(LayoutParserError.badData("Field defined before group")))
      }
    }

    describe("NASRTable") {
      it("finds field by identifier") {
        let distURL = Bundle.module.resourceURL!.appendingPathComponent(
          "MockDistribution",
          isDirectory: true
        )
        let distribution = DirectoryDistribution(location: distURL)
        let parser = MockParser()

        try await parser.prepare(distribution: distribution)

        let firstFormat = parser.formats[0]

        // A1 is the "ASSOCIATED CITY NAME" field in APT record
        let field = firstFormat.field(forID: "A1")
        expect(field).toNot(beNil())
        expect(field?.identifier).to(equal(.number("A1")))
      }

      it("returns nil for unknown identifier") {
        let distURL = Bundle.module.resourceURL!.appendingPathComponent(
          "MockDistribution",
          isDirectory: true
        )
        let distribution = DirectoryDistribution(location: distURL)
        let parser = MockParser()

        try await parser.prepare(distribution: distribution)

        let firstFormat = parser.formats[0]

        let field = firstFormat.field(forID: "NONEXISTENT")
        expect(field).to(beNil())
      }

      it("finds field offset by identifier") {
        let distURL = Bundle.module.resourceURL!.appendingPathComponent(
          "MockDistribution",
          isDirectory: true
        )
        let distribution = DirectoryDistribution(location: distURL)
        let parser = MockParser()

        try await parser.prepare(distribution: distribution)

        let firstFormat = parser.formats[0]

        // A1 should be at a specific offset in the fields array
        let offset = firstFormat.fieldOffset(forID: "A1")
        expect(offset).toNot(beNil())

        // Verify it points to the correct field
        if let offset = offset {
          expect(firstFormat.fields[offset].identifier).to(equal(.number("A1")))
        }
      }
    }
  }
}
