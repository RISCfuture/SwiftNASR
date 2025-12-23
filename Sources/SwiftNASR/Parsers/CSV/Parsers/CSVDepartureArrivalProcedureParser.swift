import Foundation
import StreamingCSV

/// CSV Departure/Arrival Procedure Parser for parsing DP/STAR CSV files.
///
/// Parses DP_BASE.csv, DP_APT.csv, DP_RTE.csv, STAR_BASE.csv, STAR_APT.csv, and STAR_RTE.csv.
actor CSVDepartureArrivalProcedureParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = [
    "DP_BASE.csv", "DP_APT.csv", "DP_RTE.csv",
    "STAR_BASE.csv", "STAR_APT.csv", "STAR_RTE.csv"
  ]

  /// Procedures keyed by computer code
  var procedures = [String: DepartureArrivalProcedure]()

  /// Sequence number counter for generating unique sequence numbers
  private var sequenceCounter: UInt = 0

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse DP_BASE.csv
    try await parseCSVFile(
      filename: "DP_BASE.csv",
      requiredColumns: ["DP_NAME", "DP_COMPUTER_CODE"]
    ) { row in
      let name = try row["DP_NAME"]
      let computerCode = try row["DP_COMPUTER_CODE"]
      guard !computerCode.isEmpty else { return }

      let key = "D-\(computerCode)"

      // Generate a unique sequence number for this procedure
      self.sequenceCounter += 1
      let sequenceNumber = String(format: "%05d", self.sequenceCounter)

      let procedure = DepartureArrivalProcedure(
        procedureType: .DP,
        sequenceNumber: sequenceNumber,
        computerCode: computerCode,
        name: name.isEmpty ? nil : name
      )

      self.procedures[key] = procedure
    }

    // Parse STAR_BASE.csv
    try await parseCSVFile(
      filename: "STAR_BASE.csv",
      requiredColumns: ["ARRIVAL_NAME", "STAR_COMPUTER_CODE"]
    ) { row in
      let name = try row["ARRIVAL_NAME"]
      let computerCode = try row["STAR_COMPUTER_CODE"]
      guard !computerCode.isEmpty else { return }

      let key = "S-\(computerCode)"

      // Generate a unique sequence number for this procedure
      self.sequenceCounter += 1
      let sequenceNumber = String(format: "%05d", self.sequenceCounter)

      let procedure = DepartureArrivalProcedure(
        procedureType: .STAR,
        sequenceNumber: sequenceNumber,
        computerCode: computerCode,
        name: name.isEmpty ? nil : name
      )

      self.procedures[key] = procedure
    }

    // Parse DP_APT.csv for adapted airports
    try await parseCSVFile(
      filename: "DP_APT.csv",
      requiredColumns: ["DP_COMPUTER_CODE", "ARPT_ID"]
    ) { row in
      let computerCode = try row["DP_COMPUTER_CODE"]
      let airportId = try row["ARPT_ID"]
      let runwayEndId = row[ifExists: "RWY_END_ID"]

      guard !computerCode.isEmpty, !airportId.isEmpty else { return }
      let key = "D-\(computerCode)"
      guard self.procedures[key] != nil else { return }

      // Check if this airport/runway combo already exists
      let existingAirports = self.procedures[key]!.adaptedAirports
      let alreadyExists = existingAirports.contains { apt in
        apt.identifier == airportId && apt.runwayEndID == runwayEndId
      }
      guard !alreadyExists else { return }

      let airport = DepartureArrivalProcedure.AdaptedAirport(
        position: nil,
        identifier: airportId,
        runwayEndID: runwayEndId
      )

      self.procedures[key]?.adaptedAirports.append(airport)
    }

    // Parse STAR_APT.csv for adapted airports
    try await parseCSVFile(
      filename: "STAR_APT.csv",
      requiredColumns: ["STAR_COMPUTER_CODE", "ARPT_ID"]
    ) { row in
      let computerCode = try row["STAR_COMPUTER_CODE"]
      let airportId = try row["ARPT_ID"]
      let runwayEndId = row[ifExists: "RWY_END_ID"]

      guard !computerCode.isEmpty, !airportId.isEmpty else { return }
      let key = "S-\(computerCode)"
      guard self.procedures[key] != nil else { return }

      // Check if this airport/runway combo already exists
      let existingAirports = self.procedures[key]!.adaptedAirports
      let alreadyExists = existingAirports.contains { apt in
        apt.identifier == airportId && apt.runwayEndID == runwayEndId
      }
      guard !alreadyExists else { return }

      let airport = DepartureArrivalProcedure.AdaptedAirport(
        position: nil,
        identifier: airportId,
        runwayEndID: runwayEndId
      )

      self.procedures[key]?.adaptedAirports.append(airport)
    }

    // Parse DP_RTE.csv for route points
    try await parseCSVFile(
      filename: "DP_RTE.csv",
      requiredColumns: ["DP_COMPUTER_CODE", "ROUTE_PORTION_TYPE", "POINT", "POINT_TYPE"]
    ) { row in
      let computerCode = try row["DP_COMPUTER_CODE"]
      let routePortionType = try row["ROUTE_PORTION_TYPE"]
      let routeName = row[ifExists: "ROUTE_NAME"] ?? ""
      let transitionCode = row[ifExists: "TRANSITION_COMPUTER_CODE"] ?? ""
      let pointSeq = row[ifExists: "POINT_SEQ"] ?? ""
      let point = try row["POINT"]
      let ICAORegionCode = row[ifExists: "ICAO_REGION_CODE"] ?? ""
      let pointType = try row["POINT_TYPE"]

      guard !computerCode.isEmpty, !point.isEmpty else { return }
      let key = "D-\(computerCode)"
      guard self.procedures[key] != nil else { return }

      let fixType = self.parseFixType(pointType)
      let routePoint = DepartureArrivalProcedure.Point(
        fixType: fixType,
        position: nil,
        identifier: point,
        ICAORegionCode: ICAORegionCode.isEmpty ? nil : ICAORegionCode,
        airwaysNavaids: nil
      )

      if routePortionType.uppercased() == "TRANSITION" && !transitionCode.isEmpty {
        // Add to transitions
        self.addPointToTransition(
          key: key,
          transitionCode: transitionCode,
          transitionName: routeName,
          point: routePoint,
          pointSeq: pointSeq
        )
      } else {
        // Add to main body
        self.procedures[key]?.points.append(routePoint)
      }
    }

    // Parse STAR_RTE.csv for route points
    try await parseCSVFile(
      filename: "STAR_RTE.csv",
      requiredColumns: ["STAR_COMPUTER_CODE", "ROUTE_PORTION_TYPE", "POINT", "POINT_TYPE"]
    ) { row in
      let computerCode = try row["STAR_COMPUTER_CODE"]
      let routePortionType = try row["ROUTE_PORTION_TYPE"]
      let routeName = row[ifExists: "ROUTE_NAME"] ?? ""
      let transitionCode = row[ifExists: "TRANSITION_COMPUTER_CODE"] ?? ""
      let pointSeq = row[ifExists: "POINT_SEQ"] ?? ""
      let point = try row["POINT"]
      let ICAORegionCode = row[ifExists: "ICAO_REGION_CODE"] ?? ""
      let pointType = try row["POINT_TYPE"]

      guard !computerCode.isEmpty, !point.isEmpty else { return }
      let key = "S-\(computerCode)"
      guard self.procedures[key] != nil else { return }

      let fixType = self.parseFixType(pointType)
      let routePoint = DepartureArrivalProcedure.Point(
        fixType: fixType,
        position: nil,
        identifier: point,
        ICAORegionCode: ICAORegionCode.isEmpty ? nil : ICAORegionCode,
        airwaysNavaids: nil
      )

      if routePortionType.uppercased() == "TRANSITION" && !transitionCode.isEmpty {
        // Add to transitions
        self.addPointToTransition(
          key: key,
          transitionCode: transitionCode,
          transitionName: routeName,
          point: routePoint,
          pointSeq: pointSeq
        )
      } else {
        // Add to main body
        self.procedures[key]?.points.append(routePoint)
      }
    }
  }

  /// Adds a point to a transition, creating the transition if it doesn't exist.
  private func addPointToTransition(
    key: String,
    transitionCode: String,
    transitionName: String,
    point: DepartureArrivalProcedure.Point,
    pointSeq _: String
  ) {
    guard var procedure = procedures[key] else { return }

    // Find or create the transition
    if let transitionIndex = procedure.transitions.firstIndex(where: {
      $0.computerCode == transitionCode
    }) {
      procedure.transitions[transitionIndex].points.append(point)
    } else {
      // Extract name from route name (e.g., "SAPPO TRANSITION" -> "SAPPO")
      let name = transitionName.replacingOccurrences(of: " TRANSITION", with: "")
        .trimmingCharacters(in: .whitespaces)
      var transition = DepartureArrivalProcedure.Transition(
        computerCode: transitionCode,
        name: name.isEmpty ? nil : name,
        points: []
      )
      transition.points.append(point)
      procedure.transitions.append(transition)
    }

    procedures[key] = procedure
  }

  /// Parses CSV point type to FixType.
  private func parseFixType(_ pointType: String) -> DepartureArrivalProcedure.FixType {
    let trimmed = pointType.trimmingCharacters(in: .whitespaces)
    switch trimmed.uppercased() {
      case "WP": return .waypoint
      case "RP": return .reportingPoint
      case "CN": return .computerNavigationFix
      case "VORTAC": return .navaidVORTAC
      case "VOR/DME": return .navaidVOR_DME
      case "VOR": return .navaidVOR
      case "NDB": return .navaidRBN
      case "NDB/DME": return .navaidRBN  // Closest match
      case "DME": return .DME
      case "TACAN": return .navaidTACAN
      default:
        // Default to waypoint for unknown types
        return .waypoint
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(departureArrivalProceduresComplete: Array(procedures.values))
  }
}
