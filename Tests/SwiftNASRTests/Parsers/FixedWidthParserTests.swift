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

  // MARK: coded flags

  /// Without a `falseValue` a flag is lenient: anything but the true value
  /// reads as `false`. The airway MEA gap indicator codes `U` against `N`, so
  /// it supplies one and an unexpected code is reported instead.
  @Test
  func `reads a coded flag strictly when a false value is given`() throws {
    let lenient = ByteTransformer([.recordType, .boolean(trueValue: "U")])
    let strict = ByteTransformer([.recordType, .boolean(trueValue: "U", falseValue: "N")])

    func slices(_ flag: String) -> [ByteSlice] {
      [Array("AWY1".utf8)[...], Array(flag.utf8)[...]]
    }

    #expect(try lenient.applyTo(slices("U"))[1] as Bool == true)
    #expect(try lenient.applyTo(slices("N"))[1] as Bool == false)
    #expect(try lenient.applyTo(slices("?"))[1] as Bool == false)

    #expect(try strict.applyTo(slices("U"))[1] as Bool == true)
    #expect(try strict.applyTo(slices("N"))[1] as Bool == false)
    #expect {
      try strict.applyTo(slices("?"))
    } throws: { error in
      guard case let FixedWidthParserError.invalidValue(value, index) = error else { return false }
      return value == "?" && index == 1
    }
  }

  // MARK: orphaned child records

  /// Child records naming a site number with no airport record are reported
  /// rather than skipped. A dropped airport otherwise takes its runways,
  /// remarks, arresting systems, and attendance schedules down with it without
  /// anything appearing in the error handler.
  @Test
  func `reports airport child records whose site number has no airport`() async throws {
    let parser = FixedWidthAirportParser()
    let site = "00000.*A"

    func slices(_ fields: [String]) -> [ByteSlice] {
      fields.map { Array($0.utf8)[...] }
    }

    func isOrphan(_ error: any Swift.Error, _ childType: String) -> Bool {
      guard case let ParserError.unknownParentRecord(parentType, parentID, child) = error else {
        return false
      }
      return parentType == "Airport" && parentID == site && child == childType
    }

    await #expect {
      try await parser.parseRunwayRecord(slices(["RWY", site]))
    } throws: { isOrphan($0, "runway") }

    await #expect {
      try await parser.parseRemarkRecord(slices(["RMK", site, "AK", "A110-1", "a remark"]))
    } throws: { isOrphan($0, "remark") }

    await #expect {
      try await parser.parseArrestingSystemRecord(
        slices(["ARS", site, "AK", "18/36", "18", "BAK-12", ""])
      )
    } throws: { isOrphan($0, "arresting system") }

    await #expect {
      try await parser.parseAttendanceRecord(
        slices(["ATT", site, "AK", "1", "ALL/ALL/ALL", ""])
      )
    } throws: { isOrphan($0, "attendance schedule") }
  }

  // MARK: pavement classification

  @Test(arguments: ["61", "PCN/560/R/B/W", "PCN//R/B/X/T", "PCN/61/R/B/X/T/U", "61/R/B/X/T"])
  func `reports an invalid pavement classification for a value without six components`(
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
  func `parses a six component pavement classification`() throws {
    let classification = try FixedWidthAirportParser.parsePavementClassification("PCN/61  /R/B/X/T")

    #expect(classification.ratingSystem == .PCN)
    #expect(classification.number == 61)
    #expect(classification.type == .rigid)
    #expect(classification.subgradeStrengthCategory == .medium)
    #expect(classification.tirePressureLimit == .high)
    #expect(classification.determinationMethod == .technical)
  }

  @Test
  func `parses a pavement classification rating`() throws {
    let classification = try FixedWidthAirportParser.parsePavementClassification("PCR/2110/F/B/X/T")

    #expect(classification.ratingSystem == .PCR)
    #expect(classification.number == 2110)
    #expect(classification.type == .flexible)
  }
}
