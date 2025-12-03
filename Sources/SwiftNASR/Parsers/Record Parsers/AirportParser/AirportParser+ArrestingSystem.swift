extension AirportParser {
  private var arrestingSystemTransformer: FixedWidthTransformer {
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

  func parseArrestingSystemRecord(_ values: [String]) throws {
    let transformedValues = try arrestingSystemTransformer.applyTo(values)

    let airportID = transformedValues[1] as! String
    guard let airport = airports[airportID] else { return }

    guard
      let runwayIndex = airport.runways.firstIndex(where: {
        $0.identification == transformedValues[3] as! String
      })
    else { return }
    let runway = airport.runways[runwayIndex]

    let runwayEndIdentifier = transformedValues[4] as! String
    let runwayEnd: RunwayEndType =
      if runway.baseEnd.ID == runwayEndIdentifier {
        .base
      } else if runway.reciprocalEnd?.ID == runwayEndIdentifier { .reciprocal } else {
        throw FixedWidthParserError.invalidValue(runwayEndIdentifier, at: 4)
      }

    let type = transformedValues[5] as! String

    switch runwayEnd {
      case .base:
        airports[airportID]!.runways[runwayIndex].baseEnd.arrestingSystems.append(type)
      case .reciprocal:
        airports[airportID]!.runways[runwayIndex].reciprocalEnd!.arrestingSystems.append(type)
    }
  }
}
