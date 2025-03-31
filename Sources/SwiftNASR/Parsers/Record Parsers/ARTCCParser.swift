import Foundation

enum ARTCCRecordIdentifier: String {
    case generalData = "AFF1"
    case remarks = "AFF2"
    case frequencies = "AFF3"
    case frequencyRemarks = "AFF4"
}

struct ARTCCKey: Hashable {
    let ID: String
    let location: String
    let type: ARTCC.FacilityType

    init(center: ARTCC) {
        ID = center.ID
        location = center.locationName
        type = center.type
    }

    init(values: [Any?]) {
        ID = values[1] as! String
        location = values[2] as! String
        type = values[3] as! ARTCC.FacilityType
    }
}

class ARTCCParser: FixedWidthParser {
    typealias RecordIdentifier = ARTCCRecordIdentifier

    static let type: RecordType = .ARTCCFacilities
    static let layoutFormatOrder: [RecordIdentifier] = [.generalData, .remarks, .frequencies, .frequencyRemarks]

    var recordTypeRange: Range<UInt> { 0..<4 }
    var formats = [NASRTable]()
    var ARTCCs = [ARTCCKey: ARTCC]()

    private let generalTransformer = FixedWidthTransformer([
        .recordType,                                                            //  0 record type
        .string(),                                                              //  1 identifier

        .string(),                                                              //  2 name
        .string(),                                                              //  3 location name
        .string(nullable: .blank),                                              //  4 cross reference

        .generic { try raw($0, toEnum: ARTCC.FacilityType.self) },              //  5 facility type
        .null,                                                                  //  6 effective date
        .null,                                                                  //  7 state name
        .string(nullable: .blank),                                              //  8 state PO code

        .DDMMSS(nullable: .blank),                                              //  9 latitude - formatted
        .null,                                                                  // 10 latitude - decimal
        .DDMMSS(nullable: .blank),                                              // 11 longitude - formatted
        .null,                                                                  // 12 longitude - decimal
        .string(nullable: .blank),                                              // 13 ICAO ID
        .null                                                                   // 14 blank
    ])

    private let remarksTransformer = FixedWidthTransformer([
        .recordType,                                                            // 0 record type
        .string(),                                                              // 1 ARTCC ID
        .string(),                                                              // 2 ARTCC location
        .generic { try raw($0, toEnum: ARTCC.FacilityType.self) },              // 3 facility type
        .unsignedInteger(),                                                     // 4 sequence number
        .string(),                                                              // 5 remark
        .null                                                                   // 6 blank
    ])

    private let frequencyTransformer = FixedWidthTransformer([
        .recordType,                                                            //  0 record type
        .string(),                                                              //  1 ARTCC ID
        .string(),                                                              //  2 ARTCC location
        .generic { try raw($0, toEnum: ARTCC.FacilityType.self) },              //  3 facility type

        .frequency(),                                                           //  4 frequency
        .delimitedArray(delimiter: "/") { try raw($0, toEnum: ARTCC.CommFrequency.Altitude.self) }, //  5 altitude
        .string(nullable: .blank),                                              //  6 special usage name
        .boolean(nullable: .blank),                                             //  7 RCAG freq charted flag

        .string(nullable: .blank),                                              //  8 landing facility LID
        .null,                                                                  //  9 state name
        .null,                                                                  // 10 state PO code
        .null,                                                                  // 11 city name
        .null,                                                                  // 12 airport name
        .null,                                                                  // 13 airport latitude - formatted
        .null,                                                                  // 14 airport latitude - seconds
        .null,                                                                  // 15 airport longitude - formatted
        .null                                                                   // 16 airport longitude - seconds
    ])

    private let frequencyRemarksTransformer = FixedWidthTransformer([
        .recordType,                                                            // 0 record type
        .string(),                                                              // 1 ARTCC ID
        .string(),                                                              // 2 ARTCC location
        .generic { try raw($0, toEnum: ARTCC.FacilityType.self) },              // 3 facility type
        .frequency(),                                                           // 4 frequency
        .unsignedInteger(),                                                     // 5 sequence number
        .string(),                                                              // 6 remark
        .null                                                                   // 7 blank
    ])

    func parseValues(_ values: [String], for identifier: ARTCCRecordIdentifier) throws {
        switch identifier {
            case .generalData: try parseGeneralRecord(values)
            case .remarks: try parseRemarks(values)
            case .frequencies: try parseFrequency(values)
            case .frequencyRemarks: try parseFrequencyRemarks(values)
        }
    }

    func finish(data: NASRData) async {
        await data.finishParsing(ARTCCs: Array(ARTCCs.values))
    }

    private func parseGeneralRecord(_ values: [String]) throws {
        let transformedValues = try generalTransformer.applyTo(values)

        var location: Location?
        if transformedValues[9] != nil && transformedValues[11] != nil {
            location = Location(latitude: transformedValues[9] as! Float,
                                longitude: transformedValues[11] as! Float,
                                elevation: nil)
        }

        let center = ARTCC(ID: transformedValues[1] as! String,
                           ICAOID: transformedValues[13] as! String?,
                           type: transformedValues[5] as! ARTCC.FacilityType,
                           name: transformedValues[2] as! String,
                           alternateName: transformedValues[4] as! String?,
                           locationName: transformedValues[3] as! String,
                           stateCode: transformedValues[8] as! String?,
                           location: location)

        ARTCCs[ARTCCKey(center: center)] = center
    }

    private func parseRemarks(_ values: [String]) throws {
        let transformedValues = try remarksTransformer.applyTo(values)
        try updateARTCC(transformedValues) { center in
            center.remarks.append(.general(transformedValues[5] as! String))
        }
    }

    private func parseFrequency(_ values: [String]) throws {
        let transformedValues = try frequencyTransformer.applyTo(values)

        try updateARTCC(transformedValues) { center in
            let frequency = ARTCC.CommFrequency(frequency: transformedValues[4] as! UInt,
                                                altitude: transformedValues[5] as! [ARTCC.CommFrequency.Altitude],
                                                specialUsageName: transformedValues[6] as! String?,
                                                remoteOutletFrequencyCharted: transformedValues[7] as! Bool?,
                                                associatedAirportCode: transformedValues[8] as! String?)
            center.frequencies.append(frequency)
        }
    }

    private func parseFrequencyRemarks(_ values: [String]) throws {
        let transformedValues = try frequencyRemarksTransformer.applyTo(values)

        try updateARTCC(transformedValues) { center in
            guard let freqIndex = center.frequencies.firstIndex(where: { $0.frequency == transformedValues[4] as! UInt }) else {
                throw Error.unknownARTCCFrequency(transformedValues[4] as! UInt, ARTCC: center)
            }
            center.frequencies[freqIndex].remarks.append(.general(transformedValues[6] as! String))
        }
    }

    private func updateARTCC(_ values: [Any?], process: (inout ARTCC) throws -> Void) throws {
        guard var center = ARTCCs[ARTCCKey(values: values)] else {
            throw Error.unknownARTCC(values[1] as! String)
        }

        try process(&center)
        ARTCCs[ARTCCKey(values: values)] = center
    }
}
