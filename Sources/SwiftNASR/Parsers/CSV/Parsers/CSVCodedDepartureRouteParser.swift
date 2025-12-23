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

  private let transformer = CSVTransformer([
    .init("RCode", .string()),
    .init("Orig", .string()),
    .init("Dest", .string()),
    .init("DepFix", .string()),
    .init("Route String", .string()),
    .init("DCNTR", .string()),
    .init("ACNTR", .string(nullable: .blank)),
    .init("TCNTRs", .string(nullable: .blank)),
    .init("CoordReq", .string(nullable: .blank)),
    .init("Play", .string(nullable: .blank)),
    .init("NavEqp", .string(nullable: .blank)),
    .init("Length", .unsignedInteger(nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    try await parseCSVFile(
      filename: "CDR.csv",
      requiredColumns: ["RCode", "Orig", "Dest", "DepFix", "Route String", "DCNTR"]
    ) { row in
      let t = try self.transformer.applyTo(row)

      let routeCode: String = try t["RCode"]

      // Parse CoordReq (Y/N) to Bool
      let coordReqString: String? = try t[optional: "CoordReq"]
      let coordinationRequired: Bool?
      switch coordReqString?.uppercased() {
        case "Y": coordinationRequired = true
        case "N": coordinationRequired = false
        default: coordinationRequired = nil
      }

      let route = CodedDepartureRoute(
        routeCode: routeCode,
        origin: try t["Orig"],
        destination: try t["Dest"],
        departureFix: try t["DepFix"],
        routeString: try t["Route String"],
        departureCenterIdentifier: try t["DCNTR"],
        arrivalCenterIdentifier: try t[optional: "ACNTR"],
        transitionCenterIdentifiers: try t[optional: "TCNTRs"],
        coordinationRequired: coordinationRequired,
        playInfo: try t[optional: "Play"],
        navigationEquipment: try t[optional: "NavEqp"],
        lengthNM: try t[optional: "Length"]
      )

      self.routes[routeCode] = route
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(codedDepartureRoutes: Array(routes.values))
  }
}
