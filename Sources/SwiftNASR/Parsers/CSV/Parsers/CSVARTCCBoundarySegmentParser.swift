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

  private let transformer = CSVTransformer([
    .init("EFF_DATE", .null),
    .init("REC_ID", .string()),
    .init("LOCATION_ID", .string()),
    .init("LOCATION_NAME", .string()),
    .init("ALTITUDE", .string()),
    .init("POINT_SEQ", .unsignedInteger()),
    .init("LAT_DECIMAL", .float()),
    .init("LONG_DECIMAL", .float()),
    .init("BNDRY_PT_DESCRIP", .string(nullable: .blank)),
    .init("NAS_DESCRIP_FLAG", .boolean(trueValue: "X", nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    try await parseCSVFile(
      filename: "ARB_SEG.csv",
      requiredColumns: ["REC_ID", "LOCATION_ID", "LAT_DECIMAL", "LONG_DECIMAL", "POINT_SEQ"]
    ) { row in
      let t = try self.transformer.applyTo(row)

      let recordId: String = try t["REC_ID"]
      guard !recordId.isEmpty else { return }

      // Parse record identifier components: "ZAB*H*53855" -> (ZAB, H, 53855)
      let (ARTCCId, altitudeCode, pointDesignator) = parseRecordIdentifier(recordId)

      // Parse location - convert from decimal degrees to arc-seconds
      let latitude: Float = try t["LAT_DECIMAL"]
      let longitude: Float = try t["LONG_DECIMAL"]
      let position = Location(
        latitudeArcsec: latitude * 3600,
        longitudeArcsec: longitude * 3600
      )

      let segment = ARTCCBoundarySegment(
        recordIdentifier: recordId,
        ARTCCIdentifier: ARTCCId,
        altitudeStructure: ARTCCBoundarySegment.AltitudeStructure(rawValue: altitudeCode),
        pointDesignator: pointDesignator,
        centerName: try t["LOCATION_NAME"],
        altitudeStructureName: try t["ALTITUDE"],
        position: position,
        boundaryDescription: try t[optional: "BNDRY_PT_DESCRIP"] ?? "",
        sequenceNumber: try t["POINT_SEQ"],
        NASDescriptionOnly: try t[optional: "NAS_DESCRIP_FLAG"]
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
