import Foundation

/// Parser for ARB (ARTCC Boundary Segments) files.
///
/// These files contain boundary segment information for Air Route Traffic Control Centers.
/// Records are 397 characters fixed-width with a single record type.
///
/// Note: This parser uses hardcoded field positions because the FAA layout file
/// does not contain group separators required by the layout parser.
class FixedWidthARTCCBoundarySegmentParser: Parser {
  // Field positions (0-indexed start, length)
  private static let fields: [(Int, Int)] = [
    (0, 12),  // record identifier
    (12, 40),  // center name
    (52, 10),  // altitude structure decode name
    (62, 14),  // latitude
    (76, 14),  // longitude
    (90, 300),  // boundary description
    (390, 6),  // sequence number
    (396, 1)  // NAS description only flag
  ]

  var segments = [ARTCCBoundarySegment]()

  private let transformer = FixedWidthTransformer([
    .string(),  // 0 record identifier (12)
    .string(),  // 1 center name (40)
    .string(),  // 2 altitude structure decode name (10)
    .generic({ try parseDecimalDegreesLatitude($0) }),  // 3 latitude (14)
    .generic({ try parseDecimalDegreesLongitude($0) }),  // 4 longitude (14)
    .string(),  // 5 boundary description (300)
    .unsignedInteger(),  // 6 sequence number (6)
    .boolean(trueValue: "X", nullable: .blank)  // 7 NAS description only flag (1)
  ])

  func prepare(distribution _: Distribution) throws {
    // No layout file parsing needed - using hardcoded field positions
  }

  func parse(data: Data) throws {
    guard data.count >= 12 else {
      throw ParserError.truncatedRecord(
        recordType: "ARB",
        expectedMinLength: 12,
        actualLength: data.count
      )
    }

    // Extract field values using hardcoded positions
    let values = Self.fields.map { start, length -> String in
      guard start < data.count else { return "" }
      let range = start..<min(start + length, data.count)
      return String(data: data[range], encoding: .isoLatin1) ?? ""
    }

    let transformedValues = try transformer.applyTo(values)

    let recordId = (transformedValues[0] as! String).trimmingCharacters(in: .whitespaces)
    guard !recordId.isEmpty else {
      throw ParserError.missingRequiredField(field: "recordIdentifier", recordType: "ARB")
    }

    // Parse the record identifier components
    // Format: ARTCC ID (3) + Altitude code (1) + Point designator (8)
    let ARTCCId = String(recordId.prefix(3)).trimmingCharacters(in: .whitespaces)
    let altitudeCode: String
    let pointDesignator: String
    if recordId.count >= 4 {
      altitudeCode = String(recordId[recordId.index(recordId.startIndex, offsetBy: 3)])
      pointDesignator =
        recordId.count > 4
        ? String(recordId.dropFirst(4)).trimmingCharacters(in: .whitespaces) : ""
    } else {
      altitudeCode = ""
      pointDesignator = ""
    }

    let lat = transformedValues[3] as! Double
    let lon = transformedValues[4] as! Double
    let position = Location(latitude: lat, longitude: lon)

    let segment = ARTCCBoundarySegment(
      recordIdentifier: recordId,
      ARTCCIdentifier: ARTCCId,
      altitudeStructure: ARTCCBoundarySegment.AltitudeStructure(rawValue: altitudeCode),
      pointDesignator: pointDesignator,
      centerName: transformedValues[1] as! String,
      altitudeStructureName: transformedValues[2] as! String,
      position: position,
      boundaryDescription: transformedValues[5] as! String,
      sequenceNumber: transformedValues[6] as! UInt,
      NASDescriptionOnly: transformedValues[7] as? Bool
    )

    segments.append(segment)
  }

  func finish(data: NASRData) async {
    await data.finishParsing(ARTCCBoundarySegments: segments)
  }
}
