import Foundation

/// Parser for `CDR.txt` (Coded Departure Routes) in the fixed-width distribution.
///
/// Unlike the other TXT-format files, `CDR.txt` is comma-delimited with no header
/// row. Each line has six fields:
///
/// ```
/// RouteCode,Origin,Destination,DepartureFix,RouteString,DepartureCenter
/// ```
///
/// This is a reduced subset of the CSV ``CodedDepartureRoute`` data (which carries
/// twelve fields); the six CSV-only fields are left `nil` when parsing from TXT. The
/// route string is space-delimited and never contains commas, so simple comma
/// splitting is safe.
actor TXTCodedDepartureRouteParser: Parser, DiagnosingParser {
  static let type = RecordType.codedDepartureRoutes

  /// The number of comma-separated fields expected in each `CDR.txt` line.
  private static let fieldCount = 6

  var pendingDiagnostics = [RecordParseError]()
  var routes = [String: CodedDepartureRoute]()

  func prepare(distribution _: Distribution) throws {
    // No layout file or distribution state is needed; CDR.txt is read line-by-line.
  }

  func parse(data: Data) throws {
    // The TXT loader yields one line per call (newline-stripped). FAA files use
    // Latin-1 encoding.
    guard let line = String(bytes: data, encoding: .isoLatin1) else {
      recordDroppedRow(ParserError.badData("CDR.txt line is not valid Latin-1"))
      return
    }

    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedLine.isEmpty else { return }

    let fields = trimmedLine.split(separator: ",", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespaces) }
    guard fields.count >= Self.fieldCount else {
      recordDroppedRow(
        ParserError.truncatedRecord(
          recordType: "CDR",
          expectedMinLength: Self.fieldCount,
          actualLength: fields.count
        ),
        id: fields.first
      )
      return
    }

    let routeCode = fields[0]
    let route = CodedDepartureRoute(
      routeCode: routeCode,
      origin: fields[1],
      destination: fields[2],
      departureFix: fields[3],
      routeString: fields[4],
      departureCenterIdentifier: fields[5],
      arrivalCenterIdentifier: nil,
      transitionCenterIdentifiers: nil,
      coordinationRequired: nil,
      playInfo: nil,
      navigationEquipment: nil,
      lengthNM: nil
    )
    routes[routeCode] = route
  }

  func finish(data: NASRData) async {
    await data.finishParsing(codedDepartureRoutes: Array(routes.values))
  }
}
