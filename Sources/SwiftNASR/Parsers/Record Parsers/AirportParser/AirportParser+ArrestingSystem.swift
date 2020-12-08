fileprivate let arrestingSystemTransformer = FixedWidthTransformer([
    .recordType,                                                                // 0 record type
    .string(),                                                                  // 1 site number
    .string(nullable: .blank),                                                  // 2 state post office code
    .string(),                                                                  // 3 runway identification
    .string(),                                                                  // 4 runway end identification
    .string(),                                                                  // 5 arresting device
    .null                                                                       // 6 blank
])

extension AirportParser {
    func parseArrestingSystemRecord(_ values: Array<String>) throws {
        let transformedValues = try arrestingSystemTransformer.applyTo(values)
        
        guard let airport = airports[transformedValues[1] as! String] else { return }
        guard let runway = airport.runways.first(where: { $0.identification  == transformedValues[3] as! String }) else { return }
        let runwayEndIdentifier = transformedValues[4] as! String
        var threshold: RunwayEnd
        if runway.baseEnd.ID == runwayEndIdentifier {
            threshold = runway.baseEnd
        } else if runway.reciprocalEnd?.ID == runwayEndIdentifier {
            threshold = runway.reciprocalEnd!
        } else {
            throw FixedWidthParserError.invalidValue(runwayEndIdentifier, at: 4)
        }
        
        let type = transformedValues[5] as! String
        threshold.arrestingSystems.append(type)
    }
}
