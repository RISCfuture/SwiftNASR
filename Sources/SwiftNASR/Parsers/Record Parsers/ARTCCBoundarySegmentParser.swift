import Foundation

/// Parser for ARB (ARTCC Boundary Segments) files.
///
/// These files contain boundary segment information for Air Route Traffic Control Centers.
/// Records are 397 characters fixed-width with a single record type.
///
/// Note: This parser uses hardcoded field positions because the FAA layout file
/// does not contain group separators required by the layout parser.
actor FixedWidthARTCCBoundarySegmentParser: Parser {
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

  private let transformer = ByteTransformer([
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

    // Extract field values as byte slices using hardcoded positions
    let bytes = [UInt8](data)
    let values = Self.fields.map { start, length -> ArraySlice<UInt8> in
      guard start < bytes.count else { return bytes[0..<0] }
      let endIndex = min(start + length, bytes.count)
      return bytes[start..<endIndex]
    }

    let t = try transformer.applyTo(values),
      rawRecordId: String = try t[0],
      recordId = rawRecordId.trimmingCharacters(in: .whitespaces)
    guard !recordId.isEmpty else {
      throw ParserError.missingRequiredField(field: "recordIdentifier", recordType: "ARB")
    }

    // Parse the record identifier components
    // Format: ARTCC ID (3) + Altitude code (1) + Point designator (8)
    let ARTCCId = String(recordId.prefix(3)).trimmingCharacters(in: .whitespaces),
      altitudeCode: String,
      pointDesignator: String
    if recordId.count >= 4 {
      altitudeCode = String(recordId[recordId.index(recordId.startIndex, offsetBy: 3)])
      pointDesignator =
        recordId.count > 4
        ? String(recordId.dropFirst(4)).trimmingCharacters(in: .whitespaces) : ""
    } else {
      altitudeCode = ""
      pointDesignator = ""
    }

    let lat: Double = try t[3],
      lon: Double = try t[4],
      position = Location(latitudeDeg: lat, longitudeDeg: lon)

    let segment = ARTCCBoundarySegment(
      recordIdentifier: recordId,
      ARTCCIdentifier: ARTCCId,
      altitudeStructure: ARTCCBoundarySegment.AltitudeStructure(rawValue: altitudeCode),
      pointDesignator: pointDesignator,
      centerName: try t[1],
      altitudeStructureName: try t[2],
      position: position,
      boundaryDescription: try t[5],
      sequenceNumber: try t[6],
      NASDescriptionOnly: try t[optional: 7]
    )

    segments.append(segment)
  }

  func finish(data: NASRData) async {
    await data.finishParsing(ARTCCBoundarySegments: segments)
  }
}
