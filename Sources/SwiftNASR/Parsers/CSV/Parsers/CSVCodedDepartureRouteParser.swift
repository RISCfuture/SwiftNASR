import Foundation
import StreamingCSV
import ZIPFoundation

/// CSV Coded Departure Route Parser for parsing CDR.csv
///
/// CDR is a comma-delimited file with 6 fields:
/// Route Code, Origin, Destination, Departure Fix, Route String, ARTCC
class CSVCodedDepartureRouteParser: CSVParser {
  var csvDirectory = URL(fileURLWithPath: "/")
  var routes = [String: CodedDepartureRoute]()

  // CSV field mapping (0-based indices)
  // Fields: Route Code, Origin, Destination, Departure Fix, Route String, ARTCC
  private let csvFieldMapping: [Int] = [
    0,  // 0: Route Code
    1,  // 1: Origin
    2,  // 2: Destination
    3,  // 3: Departure Fix
    4,  // 4: Route String
    5  // 5: ARTCC
  ]

  private let transformer = CSVTransformer([
    .string(),  // 0: Route Code
    .string(),  // 1: Origin
    .string(),  // 2: Destination
    .string(),  // 3: Departure Fix
    .string(),  // 4: Route String
    .string()  // 5: ARTCC
  ])

  func prepare(distribution: Distribution) throws {
    if let dirDist = distribution as? DirectoryDistribution {
      csvDirectory = dirDist.location
    } else if let archiveDist = distribution as? ArchiveFileDistribution {
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        "SwiftNASR_CSV_\(UUID().uuidString)"
      )
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      try FileManager.default.unzipItem(at: archiveDist.location, to: tempDir)
      csvDirectory = tempDir
    }
  }

  func parse(data _: Data) async throws {
    try await parseCSVFile(filename: "CDR.csv", expectedFieldCount: 6) { fields in
      guard fields.count >= 3 else {
        throw ParserError.truncatedRecord(
          recordType: "CDR",
          expectedMinLength: 3,
          actualLength: fields.count
        )
      }

      var mappedFields = [String](repeating: "", count: 6)
      for (transformerIndex, csvIndex) in self.csvFieldMapping.enumerated()
      where csvIndex < fields.count {
        mappedFields[transformerIndex] = fields[csvIndex]
      }

      let transformedValues = try self.transformer.applyTo(
        mappedFields,
        indices: Array(0..<6)
      )

      let routeCode = transformedValues[0] as! String

      let route = CodedDepartureRoute(
        routeCode: routeCode,
        origin: transformedValues[1] as! String,
        destination: transformedValues[2] as! String,
        departureFix: transformedValues[3] as! String,
        routeString: transformedValues[4] as! String,
        ARTCCIdentifier: transformedValues[5] as! String
      )

      self.routes[routeCode] = route
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(codedDepartureRoutes: Array(routes.values))
  }
}
