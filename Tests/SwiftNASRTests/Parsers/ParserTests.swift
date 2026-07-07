import Foundation
import Testing

@testable import SwiftNASR

actor MockParser: LayoutDataParser {
  static let type = RecordType.airports
  var formats = [NASRTable]()

  func parse(data _: Data) throws {
    // do nothing
  }

  func finish(data _: NASRData) {
    // do nothing
  }
}

@Suite
struct ParserTests {
  private func distribution(_ resource: String) -> DirectoryDistribution {
    let distURL = Bundle.module.resourceURL!.appendingPathComponent(resource, isDirectory: true)
    return DirectoryDistribution(location: distURL)
  }

  private func preparedParser(_ resource: String = "MockDistribution") async throws -> MockParser {
    let parser = MockParser()
    try await parser.prepare(distribution: distribution(resource))
    return parser
  }

  // MARK: prepare

  @Test
  func parsesAllRecordFormatsFromLayoutFile() async throws {
    let parser = try await preparedParser()
    // APT layout file defines 5 record formats: APT, ATT, RWY, ARS, RMK
    let formatCount = await parser.formats.count
    #expect(formatCount == 5)
  }

  @Test
  func calculatesCorrectZeroIndexedFieldRangesFromOneIndexedPositions() async throws {
    let parser = try await preparedParser()
    let firstFormat = await parser.formats[0]

    // First field: L AN 0003 00001 -> range 0..<3
    #expect(firstFormat.fields[0].range == 0..<3)

    // Second field: L AN 0011 00004 -> range 3..<14
    #expect(firstFormat.fields[1].range == 3..<14)

    // Third field: L AN 0013 00015 -> range 14..<27
    #expect(firstFormat.fields[2].range == 14..<27)
  }

  @Test
  func correctlyParsesFieldIdentifierTypes() async throws {
    let parser = try await preparedParser()
    let firstFormat = await parser.formats[0]

    // First field has N/A identifier -> .none
    #expect(firstFormat.fields[0].identifier == NASRTableField.Identifier.none)

    // Second field has DLID identifier -> .databaseLocatorID
    #expect(firstFormat.fields[1].identifier == .databaseLocatorID)

    // Look for a numbered field (e.g., E7, A1, etc.)
    let numberedField = firstFormat.fields.first {
      if case .number = $0.identifier { return true }
      return false
    }
    #expect(numberedField != nil)
  }

  @Test
  func throwsBadDataIfAnLEntryIsInvalid() async {
    let parser = MockParser()
    let distribution = distribution("FailingMockDistribution")
    await #expect {
      try await parser.prepare(distribution: distribution)
    } throws: { error in
      guard case LayoutParserError.badData = error else { return false }
      return true
    }
  }

  // MARK: NASRTable

  @Test
  func findsFieldByIdentifier() async throws {
    let parser = try await preparedParser()
    let firstFormat = await parser.formats[0]

    // A1 is the "ASSOCIATED CITY NAME" field in APT record
    let field = firstFormat.field(forID: "A1")
    #expect(field != nil)
    #expect(field?.identifier == .number("A1"))
  }

  @Test
  func returnsNilForUnknownIdentifier() async throws {
    let parser = try await preparedParser()
    let firstFormat = await parser.formats[0]

    #expect(firstFormat.field(forID: "NONEXISTENT") == nil)
  }

  @Test
  func findsFieldOffsetByIdentifier() async throws {
    let parser = try await preparedParser()
    let firstFormat = await parser.formats[0]

    // A1 should be at a specific offset in the fields array
    let offset = firstFormat.fieldOffset(forID: "A1")
    #expect(offset != nil)

    // Verify it points to the correct field
    if let offset {
      #expect(firstFormat.fields[offset].identifier == .number("A1"))
    }
  }
}
