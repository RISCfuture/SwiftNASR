import Foundation
import StreamingCSV

/// CSV Coded Departure Route Parser for parsing CDR.csv
///
/// CDR is a comma-delimited file with 12 fields:
/// RCode, Orig, Dest, DepFix, Route String, DCNTR, ACNTR, TCNTRs, CoordReq, Play, NavEqp, Length
actor CSVCodedDepartureRouteParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["CDR.csv"]

  var routes = [String: CodedDepartureRoute]()

  // CSV field mapping (0-based indices)
  // Fields: RCode, Orig, Dest, DepFix, Route String, DCNTR, ACNTR, TCNTRs, CoordReq, Play, NavEqp, Length
  private let CSVFieldMapping: [Int] = [
    0,  // 0: RCode (Route Code)
    1,  // 1: Orig (Origin)
    2,  // 2: Dest (Destination)
    3,  // 3: DepFix (Departure Fix)
    4,  // 4: Route String
    5,  // 5: DCNTR (Departure Center)
    6,  // 6: ACNTR (Arrival Center)
    7,  // 7: TCNTRs (Transition Centers)
    8,  // 8: CoordReq (Coordination Required)
    9,  // 9: Play (Play Info)
    10,  // 10: NavEqp (Navigation Equipment)
    11  // 11: Length
  ]

  private let transformer = CSVTransformer([
    .string(),  // 0: RCode
    .string(),  // 1: Orig
    .string(),  // 2: Dest
    .string(),  // 3: DepFix
    .string(),  // 4: Route String
    .string(),  // 5: DCNTR
    .string(nullable: .blank),  // 6: ACNTR
    .string(nullable: .blank),  // 7: TCNTRs
    .string(nullable: .blank),  // 8: CoordReq (Y/N)
    .string(nullable: .blank),  // 9: Play
    .string(nullable: .blank),  // 10: NavEqp
    .unsignedInteger(nullable: .blank)  // 11: Length
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    try await parseCSVFile(filename: "CDR.csv", expectedFieldCount: 12) { fields in
      guard fields.count >= 6 else {
        throw ParserError.truncatedRecord(
          recordType: "CDR",
          expectedMinLength: 6,
          actualLength: fields.count
        )
      }

      var mappedFields = [String](repeating: "", count: 12)
      for (transformerIndex, csvIndex) in self.CSVFieldMapping.enumerated()
      where csvIndex < fields.count {
        mappedFields[transformerIndex] = fields[csvIndex]
      }

      let transformedValues = try self.transformer.applyTo(
        mappedFields,
        indices: Array(0..<12)
      )

      let routeCode = transformedValues[0] as! String

      // Parse CoordReq (Y/N) to Bool
      let coordReqString = transformedValues[8] as? String
      let coordinationRequired: Bool?
      switch coordReqString?.uppercased() {
        case "Y": coordinationRequired = true
        case "N": coordinationRequired = false
        default: coordinationRequired = nil
      }

      let route = CodedDepartureRoute(
        routeCode: routeCode,
        origin: transformedValues[1] as! String,
        destination: transformedValues[2] as! String,
        departureFix: transformedValues[3] as! String,
        routeString: transformedValues[4] as! String,
        departureCenterIdentifier: transformedValues[5] as! String,
        arrivalCenterIdentifier: transformedValues[6] as? String,
        transitionCenterIdentifiers: transformedValues[7] as? String,
        coordinationRequired: coordinationRequired,
        playInfo: transformedValues[9] as? String,
        navigationEquipment: transformedValues[10] as? String,
        lengthNM: transformedValues[11] as? UInt
      )

      self.routes[routeCode] = route
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(codedDepartureRoutes: Array(routes.values))
  }
}
