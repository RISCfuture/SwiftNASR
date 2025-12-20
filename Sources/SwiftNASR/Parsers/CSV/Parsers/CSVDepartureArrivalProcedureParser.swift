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
    // Columns: EFF_DATE(0), DP_NAME(1), AMENDMENT_NO(2), ARTCC(3), DP_AMEND_EFF_DATE(4),
    // RNAV_FLAG(5), DP_COMPUTER_CODE(6), GRAPHICAL_DP_TYPE(7), SERVED_ARPT(8)
    try await parseCSVFile(filename: "DP_BASE.csv", expectedFieldCount: 9) { fields in
      guard fields.count >= 7 else { return }

      let name = fields[1].trimmingCharacters(in: .whitespaces)
      let computerCode = fields[6].trimmingCharacters(in: .whitespaces)
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
    // Columns: EFF_DATE(0), ARRIVAL_NAME(1), AMENDMENT_NO(2), ARTCC(3), STAR_AMEND_EFF_DATE(4),
    // RNAV_FLAG(5), STAR_COMPUTER_CODE(6), SERVED_ARPT(7)
    try await parseCSVFile(filename: "STAR_BASE.csv", expectedFieldCount: 8) { fields in
      guard fields.count >= 7 else { return }

      let name = fields[1].trimmingCharacters(in: .whitespaces)
      let computerCode = fields[6].trimmingCharacters(in: .whitespaces)
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
    // Columns: EFF_DATE(0), DP_NAME(1), ARTCC(2), DP_COMPUTER_CODE(3), BODY_NAME(4),
    // BODY_SEQ(5), ARPT_ID(6), RWY_END_ID(7)
    try await parseCSVFile(filename: "DP_APT.csv", expectedFieldCount: 8) { fields in
      guard fields.count >= 7 else { return }

      let computerCode = fields[3].trimmingCharacters(in: .whitespaces)
      let airportId = fields[6].trimmingCharacters(in: .whitespaces)
      let runwayEndId = fields.count > 7 ? fields[7].trimmingCharacters(in: .whitespaces) : ""

      guard !computerCode.isEmpty, !airportId.isEmpty else { return }
      let key = "D-\(computerCode)"
      guard self.procedures[key] != nil else { return }

      // Check if this airport/runway combo already exists
      let existingAirports = self.procedures[key]!.adaptedAirports
      let alreadyExists = existingAirports.contains { apt in
        apt.identifier == airportId && apt.runwayEndID == (runwayEndId.isEmpty ? nil : runwayEndId)
      }
      guard !alreadyExists else { return }

      let airport = DepartureArrivalProcedure.AdaptedAirport(
        position: nil,
        identifier: airportId,
        runwayEndID: runwayEndId.isEmpty ? nil : runwayEndId
      )

      self.procedures[key]?.adaptedAirports.append(airport)
    }

    // Parse STAR_APT.csv for adapted airports
    // Columns: EFF_DATE(0), STAR_COMPUTER_CODE(1), ARTCC(2), BODY_NAME(3),
    // BODY_SEQ(4), ARPT_ID(5), RWY_END_ID(6)
    try await parseCSVFile(filename: "STAR_APT.csv", expectedFieldCount: 7) { fields in
      guard fields.count >= 6 else { return }

      let computerCode = fields[1].trimmingCharacters(in: .whitespaces)
      let airportId = fields[5].trimmingCharacters(in: .whitespaces)
      let runwayEndId = fields.count > 6 ? fields[6].trimmingCharacters(in: .whitespaces) : ""

      guard !computerCode.isEmpty, !airportId.isEmpty else { return }
      let key = "S-\(computerCode)"
      guard self.procedures[key] != nil else { return }

      // Check if this airport/runway combo already exists
      let existingAirports = self.procedures[key]!.adaptedAirports
      let alreadyExists = existingAirports.contains { apt in
        apt.identifier == airportId && apt.runwayEndID == (runwayEndId.isEmpty ? nil : runwayEndId)
      }
      guard !alreadyExists else { return }

      let airport = DepartureArrivalProcedure.AdaptedAirport(
        position: nil,
        identifier: airportId,
        runwayEndID: runwayEndId.isEmpty ? nil : runwayEndId
      )

      self.procedures[key]?.adaptedAirports.append(airport)
    }

    // Parse DP_RTE.csv for route points
    // Columns: EFF_DATE(0), DP_NAME(1), ARTCC(2), DP_COMPUTER_CODE(3), ROUTE_PORTION_TYPE(4),
    // ROUTE_NAME(5), BODY_SEQ(6), TRANSITION_COMPUTER_CODE(7), POINT_SEQ(8), POINT(9),
    // ICAO_REGION_CODE(10), POINT_TYPE(11), NEXT_POINT(12), ARPT_RWY_ASSOC(13)
    try await parseCSVFile(filename: "DP_RTE.csv", expectedFieldCount: 14) { fields in
      guard fields.count >= 12 else { return }

      let computerCode = fields[3].trimmingCharacters(in: .whitespaces)
      let routePortionType = fields[4].trimmingCharacters(in: .whitespaces)
      let routeName = fields[5].trimmingCharacters(in: .whitespaces)
      let transitionCode = fields.count > 7 ? fields[7].trimmingCharacters(in: .whitespaces) : ""
      let pointSeq = fields[8].trimmingCharacters(in: .whitespaces)
      let point = fields[9].trimmingCharacters(in: .whitespaces)
      let ICAORegionCode = fields[10].trimmingCharacters(in: .whitespaces)
      let pointType = fields[11].trimmingCharacters(in: .whitespaces)

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
    // Columns: EFF_DATE(0), STAR_COMPUTER_CODE(1), ARTCC(2), ROUTE_PORTION_TYPE(3),
    // ROUTE_NAME(4), BODY_SEQ(5), TRANSITION_COMPUTER_CODE(6), POINT_SEQ(7), POINT(8),
    // ICAO_REGION_CODE(9), POINT_TYPE(10), NEXT_POINT(11), ARPT_RWY_ASSOC(12)
    try await parseCSVFile(filename: "STAR_RTE.csv", expectedFieldCount: 13) { fields in
      guard fields.count >= 11 else { return }

      let computerCode = fields[1].trimmingCharacters(in: .whitespaces)
      let routePortionType = fields[3].trimmingCharacters(in: .whitespaces)
      let routeName = fields[4].trimmingCharacters(in: .whitespaces)
      let transitionCode = fields.count > 6 ? fields[6].trimmingCharacters(in: .whitespaces) : ""
      let pointSeq = fields[7].trimmingCharacters(in: .whitespaces)
      let point = fields[8].trimmingCharacters(in: .whitespaces)
      let ICAORegionCode = fields[9].trimmingCharacters(in: .whitespaces)
      let pointType = fields[10].trimmingCharacters(in: .whitespaces)

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
      case "VOR/DME": return .navaidVORDME
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
