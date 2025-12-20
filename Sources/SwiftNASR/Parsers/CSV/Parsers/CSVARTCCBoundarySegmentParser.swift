import Foundation
import StreamingCSV

/// CSV parser for ARTCC Boundary Segments.
///
/// Parses `ARB_SEG.csv` to create `ARTCCBoundarySegment` records containing
/// boundary point locations and descriptions for Air Route Traffic Control Centers.
actor CSVARTCCBoundarySegmentParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["ARB_SEG.csv"]

  var segments = [ARTCCBoundarySegment]()

  // CSV field indices for ARB_SEG.csv
  // 0: EFF_DATE, 1: REC_ID, 2: LOCATION_ID, 3: LOCATION_NAME, 4: ALTITUDE,
  // 5: TYPE, 6: POINT_SEQ, 7-10: LAT components, 11: LAT_DECIMAL,
  // 12-15: LONG components, 16: LONG_DECIMAL, 17: BNDRY_PT_DESCRIP, 18: NAS_DESCRIP_FLAG
  private let CSVFieldMapping: [Int] = [
    0,  // 0: EFF_DATE -> ignored
    1,  // 1: REC_ID -> record identifier
    2,  // 2: LOCATION_ID -> ARTCC identifier
    3,  // 3: LOCATION_NAME -> center name
    4,  // 4: ALTITUDE -> altitude structure name
    6,  // 5: POINT_SEQ -> sequence number
    11,  // 6: LAT_DECIMAL -> latitude
    16,  // 7: LONG_DECIMAL -> longitude
    17,  // 8: BNDRY_PT_DESCRIP -> boundary description
    18  // 9: NAS_DESCRIP_FLAG -> NAS description only flag
  ]

  private let transformer = CSVTransformer([
    .null,  // 0: effective date
    .string(),  // 1: record identifier
    .string(),  // 2: ARTCC identifier
    .string(),  // 3: center name
    .string(),  // 4: altitude structure name
    .unsignedInteger(),  // 5: sequence number
    .float(),  // 6: latitude decimal degrees
    .float(),  // 7: longitude decimal degrees
    .string(nullable: .blank),  // 8: boundary description
    .boolean(trueValue: "X", nullable: .blank)  // 9: NAS description only flag
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    try await parseCSVFile(filename: "ARB_SEG.csv", expectedFieldCount: 19) { fields in
      guard fields.count >= 19 else { return }

      // Map CSV fields to transformer indices
      var mappedFields = [String](repeating: "", count: 10)

      for (transformerIndex, csvIndex) in CSVFieldMapping.enumerated() {
        if csvIndex >= 0 && csvIndex < fields.count {
          mappedFields[transformerIndex] = fields[csvIndex]
        }
      }

      let transformedValues = try self.transformer.applyTo(mappedFields, indices: Array(0..<10))

      let recordId = transformedValues[1] as! String
      guard !recordId.isEmpty else { return }

      // Parse record identifier components: "ZAB*H*53855" -> (ZAB, H, 53855)
      let (ARTCCId, altitudeCode, pointDesignator) = parseRecordIdentifier(recordId)

      // Parse location - convert from decimal degrees to arc-seconds
      let latitude = transformedValues[6] as! Float
      let longitude = transformedValues[7] as! Float
      let position = Location(
        latitudeArcsec: latitude * 3600,
        longitudeArcsec: longitude * 3600
      )

      let segment = ARTCCBoundarySegment(
        recordIdentifier: recordId,
        ARTCCIdentifier: ARTCCId,
        altitudeStructure: ARTCCBoundarySegment.AltitudeStructure(rawValue: altitudeCode),
        pointDesignator: pointDesignator,
        centerName: transformedValues[3] as! String,
        altitudeStructureName: transformedValues[4] as! String,
        position: position,
        boundaryDescription: transformedValues[8] as? String ?? "",
        sequenceNumber: transformedValues[5] as! UInt,
        NASDescriptionOnly: transformedValues[9] as? Bool
      )

      segments.append(segment)
    }
  }

  /// Parses the CSV record identifier format "ZAB*H*53855" into components.
  /// - Parameter recordId: The full record identifier string.
  /// - Returns: Tuple of (ARTCC ID, altitude code, point designator).
  private func parseRecordIdentifier(_ recordId: String) -> (String, String, String) {
    let components = recordId.split(separator: "*", omittingEmptySubsequences: false)

    if components.count >= 3 {
      return (
        String(components[0]),
        String(components[1]),
        String(components[2])
      )
    }
    if components.count == 2 {
      return (
        String(components[0]),
        String(components[1]),
        ""
      )
    }
    if components.count == 1 {
      // Fallback: extract from first few characters if no delimiter
      let id = String(recordId.prefix(3))
      let altitude =
        recordId.count > 3 ? String(recordId[recordId.index(recordId.startIndex, offsetBy: 3)]) : ""
      let point = recordId.count > 4 ? String(recordId.dropFirst(4)) : ""
      return (id, altitude, point)
    }

    return (recordId, "", "")
  }

  func finish(data: NASRData) async {
    await data.finishParsing(ARTCCBoundarySegments: segments)
  }
}
