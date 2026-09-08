import Foundation
import Testing

@testable import SwiftNASR

private enum StubRecordIdentifier: String, Equatable {
  case runway = "RWY"
}

/// Slices records against a layout supplied by the test, bypassing the layout
/// file so field ranges can be stated exactly.
private actor StubFixedWidthParser: FixedWidthParser {
  static let type = RecordType.airports
  static let layoutFormatOrder: [StubRecordIdentifier] = [.runway]

  var formats = [NASRTable]()
  private(set) var parsedValues: [ArraySlice<UInt8>]?

  init(fields: [NASRTableField]) {
    formats = [.init(fields: fields)]
  }

  func parseValues(_ values: [ArraySlice<UInt8>], for _: StubRecordIdentifier) throws {
    parsedValues = values
  }

  func finish(data _: NASRData) {
    // do nothing
  }
}

@Suite
struct FixedWidthParserTests {

  /// Builds a field spanning the FAA's one-indexed `location` for `length` bytes.
  private func field(at location: UInt, length: UInt) -> NASRTableField {
    .init(identifier: .none, range: (location - 1)..<((location - 1) + length))
  }

  private func record(_ prefix: String, paddedTo length: Int) -> Data {
    Data(prefix.padding(toLength: length, withPad: " ", startingAt: 0).utf8)
  }

  // MARK: over-declared trailing filler

  @Test
  func `clamps a trailing field that runs past the end of the record`() async throws {
    // The airport layout effective 2026-09-03 ends its runway record with
    // filler at location 1147 for 390 bytes — byte 1536 of a 1532-byte record.
    let parser = StubFixedWidthParser(fields: [
      field(at: 1, length: 3),
      field(at: 4, length: 1143),
      field(at: 1147, length: 390)
    ])

    try await parser.parse(data: record("RWY", paddedTo: 1532))

    let values = try #require(await parser.parsedValues)
    #expect(values.count == 3)
    #expect(values[1].count == 1143)
    #expect(values[2].count == 1532 - 1146)
  }

  @Test
  func `clamps a trailing field that starts past the end of the record`() async throws {
    let parser = StubFixedWidthParser(fields: [
      field(at: 1, length: 3),
      field(at: 4, length: 20)
    ])

    try await parser.parse(data: record("RWY", paddedTo: 3))

    let values = try #require(await parser.parsedValues)
    #expect(values.count == 2)
    #expect(values[1].isEmpty)
  }

  // MARK: genuinely short records

  @Test
  func `reports a truncated record when a non-final field runs past the end`() async throws {
    let parser = StubFixedWidthParser(fields: [
      field(at: 1, length: 3),
      field(at: 4, length: 40),
      field(at: 44, length: 10)
    ])

    await #expect {
      try await parser.parse(data: record("RWY", paddedTo: 20))
    } throws: { error in
      guard case let ParserError.truncatedRecord(recordType, expected, actual) = error else {
        return false
      }
      return recordType == "APT" && expected == 43 && actual == 20
    }
  }

  @Test
  func `reports a truncated record when the record is shorter than its identifier`() async throws {
    let parser = StubFixedWidthParser(fields: [field(at: 1, length: 3)])

    await #expect {
      try await parser.parse(data: record("RW", paddedTo: 2))
    } throws: { error in
      guard case let ParserError.truncatedRecord(_, expected, actual) = error else { return false }
      return expected == 3 && actual == 2
    }
  }

  // MARK: well-formed records

  @Test
  func `slices a well formed record at its declared field boundaries`() async throws {
    let parser = StubFixedWidthParser(fields: [
      field(at: 1, length: 3),
      field(at: 4, length: 5),
      field(at: 9, length: 4)
    ])

    try await parser.parse(data: Data("RWYALPHABETA".utf8))

    let values = try #require(await parser.parsedValues)
    #expect(values.compactMap { $0.toString() } == ["RWY", "ALPHA", "BETA"])
  }

  // MARK: layout and transformer field counts

  @Test(arguments: [1, 3])
  func `reports a field count mismatch when the layout and transformer disagree`(
    _ sliceCount: Int
  ) throws {
    let transformer = ByteTransformer([.recordType, .string()])
    let slices = [ByteSlice](repeating: Array("X".utf8)[...], count: sliceCount)

    #expect {
      try transformer.applyTo(slices)
    } throws: { error in
      guard case let FixedWidthParserError.fieldCountMismatch(expected, actual) = error else {
        return false
      }
      return expected == 2 && actual == sliceCount
    }
  }

  // MARK: pavement classification

  @Test(arguments: ["61", "560/R/B/W", "61//B/X/T", "61/R/B/X/T/U"])
  func `reports an invalid pavement classification for a value without five components`(
    _ value: String
  ) throws {
    #expect {
      try FixedWidthAirportParser.parsePavementClassification(value)
    } throws: { error in
      guard case let SwiftNASR.Error.invalidPavementClassification(reported) = error else {
        return false
      }
      return reported == value
    }
  }

  @Test
  func `parses a five component pavement classification`() throws {
    let classification = try FixedWidthAirportParser.parsePavementClassification("61/R/B/X/T")

    #expect(classification.number == 61)
    #expect(classification.type == .rigid)
    #expect(classification.subgradeStrengthCategory == .medium)
    #expect(classification.tirePressureLimit == .high)
    #expect(classification.determinationMethod == .technical)
  }
}
