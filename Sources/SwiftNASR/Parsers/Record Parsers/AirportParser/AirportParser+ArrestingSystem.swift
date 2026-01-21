extension FixedWidthAirportParser {
  private var arrestingSystemTransformer: ByteTransformer {
    .init([
      .recordType,  // 0 record type
      .string(),  // 1 site number
      .string(nullable: .blank),  // 2 state post office code
      .string(),  // 3 runway identification
      .string(),  // 4 runway end identification
      .string(),  // 5 arresting device
      .null
    ])
  }

  func parseArrestingSystemRecord(_ values: [ArraySlice<UInt8>]) throws {
    let t = try arrestingSystemTransformer.applyTo(values)

    let airportID: String = try t[1]
    guard let airport = airports[airportID] else { return }

    let runwayId: String = try t[3]
    guard
      let runwayIndex = airport.runways.firstIndex(where: { $0.identification == runwayId })
    else { return }
    let runway = airport.runways[runwayIndex]

    let runwayEndIdentifier: String = try t[4]
    let runwayEnd: RunwayEndType =
      if runway.baseEnd.id == runwayEndIdentifier {
        .base
      } else if runway.reciprocalEnd?.id == runwayEndIdentifier { .reciprocal } else {
        throw FixedWidthParserError.invalidValue(runwayEndIdentifier, at: 4)
      }

    let type: String = try t[5]

    switch runwayEnd {
      case .base:
        airports[airportID]!.runways[runwayIndex].baseEnd.arrestingSystems.append(type)
      case .reciprocal:
        airports[airportID]!.runways[runwayIndex].reciprocalEnd!.arrestingSystems.append(type)
    }
  }
}
