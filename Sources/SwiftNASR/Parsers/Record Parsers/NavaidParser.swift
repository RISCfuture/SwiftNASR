import Foundation

enum NavaidRecordIdentifier: String {
    case basicInfo = "NAV1"
    case remark = "NAV2"
    case fixes = "NAV3"
    case holdingPatterns = "NAV4"
    case fanMarkers = "NAV5"
    case VORCheckpoint = "NAV6"
}

struct NavaidKey: Hashable {
    let ID: String
    let type: Navaid.FacilityType

    init(navaid: Navaid) {
        ID = navaid.ID
        type = navaid.type
    }

    init(values: Array<Any?>) {
        ID = values[1] as! String
        type = values[2] as! Navaid.FacilityType
    }
}

class NavaidParser: FixedWidthParser {
    typealias RecordIdentifier = NavaidRecordIdentifier

    static let type: RecordType = .navaids
    var recordTypeRange: Range<UInt> { 0..<4 }
    static let layoutFormatOrder: Array<NavaidRecordIdentifier> = [.basicInfo, .remark, .fixes, .holdingPatterns, .fanMarkers, .VORCheckpoint]
    var formats = Array<NASRTable>()

    var navaids = Dictionary<NavaidKey, Navaid>()

    private let basicTransformer = FixedWidthTransformer([
        .recordType,                                                            //  0 record type
        .string(),                                                              //  1 identifier
        .generic({ try raw($0, toEnum: Navaid.FacilityType.self) }),            //  2 facility type
        .null,                                                                  //  3 identifier

            .null,                                                                  //  4 effective date
        .string(),                                                              //  5 name
        .string(),                                                              //  6 city
        .string(nullable: .blank),                                              //  7 state name
        .null,                                                                  //  8 state PO code
        .string(),                                                              //  9 FAA region
        .string(nullable: .blank),                                              // 10 country
        .null,                                                                  // 11 country PO code
        .string(nullable: .blank),                                              // 12 owner name
        .string(nullable: .blank),                                              // 13 operator name
        .boolean(),                                                             // 14 common system
        .boolean(),                                                             // 15 public use
        .generic({ try parseClassDesignator($0) }, nullable: .blank),           // 16 navaid class
        .string(nullable: .blank),                                              // 17 hours of operation
        .string(nullable: .blank),                                              // 18 high alt ARTCC code
        .null,                                                                  // 19 high alt ARTCC name
        .string(nullable: .blank),                                              // 20 low alt ARTCC code
        .null,                                                                  // 21 low alt ARTCC name

            .DDMMSS(),                                                              // 22 latitude
        .null,                                                                  // 23 latitude (sec)
        .DDMMSS(),                                                              // 24 longitude
        .null,                                                                  // 25 longitude (sec)
        .generic({ try parseSurveyAccuracy($0) }, nullable: .blank),            // 26 survey accuracy
        .DDMMSS(nullable: .blank),                                              // 27 TACAN lat
        .null,                                                                  // 28 TACAN lat (sec)
        .DDMMSS(nullable: .blank),                                              // 29 TACAN lon
        .null,                                                                  // 30 TACAN lon (sec)
        .float(nullable: .blank),                                               // 31 elevation
        .generic({ try parseMagVar($0, fieldIndex: 32)}, nullable: .blank),     // 32 magvar
        .datetime(formatter: FixedWidthTransformer.yearOnly, nullable: .blank), // 33 magvar epoch

            .boolean(nullable: .blank),                                             // 34 simul voice output
        .unsignedInteger(nullable: .blank),                                     // 35 power output
        .boolean(nullable: .blank),                                             // 36 auto voice ident
        .generic({ try raw($0, toEnum: Navaid.MonitoringCategory.self) }, nullable: .blank), // 37 monitoring category
        .string(nullable: .sentinel(["", "NONE"])),                             // 38 radio voice call
        .generic({ try parseTACAN($0, fieldIndex: 39) }, nullable: .blank),     // 39 TACAN channel
        .frequency(nullable: .blank),                                           // 40 freq
        .string(nullable: .blank),                                              // 41 fan marker ident
        .generic({ try raw($0, toEnum: Navaid.FanMarkerType.self) }, nullable: .blank), // 42 fan marker type
        .unsignedInteger(nullable: .blank),                                     // 43 fan marker major axis
        .generic({ try parseServiceVolume($0) }, nullable: .blank),           // 44 VOR service volume
        .generic({ try parseServiceVolume($0) }, nullable: .blank),           // 45 DME service volume
        .boolean(nullable: .blank),                                             // 46 lo facility in hi structure
        .boolean(nullable: .blank),                                             // 47 Z marker
        .string(nullable: .blank),                                              // 48 TWEB hours
        .string(nullable: .blank),                                              // 49 TWEB phone
        .string(nullable: .blank),                                              // 50 FSS ident
        .null,                                                                  // 51 FSS name
        .null,                                                                  // 52 FSS hours
        .string(nullable: .blank),                                              // 53 NOTAM accountability code

            .generic({ try parseLFRLegs($0, fieldIndex: 54) }, nullable: .blank),   // 54 quadrant identification and range leg bearing

            .generic({ try raw($0, toEnum: Navaid.Status.self) }),                  // 55 status

            .boolean(),                                                             // 56 pitch flag
        .boolean(),                                                             // 57 catch flag
        .boolean(),                                                             // 58 SUA flag
        .boolean(nullable: .blank),                                             // 59 restriction flag
        .boolean(nullable: .blank),                                             // 60 hiwas flag
        .boolean(nullable: .blank)                                              // 61 tweb restriction flag
    ])

    private let remarkTransformer = FixedWidthTransformer([
        .recordType,                                                            // 0 record type
        .string(),                                                              // 1 id
        .generic({ try raw($0, toEnum: Navaid.FacilityType.self) }),            // 2 facility type

            .string(),                                                              // 3 remark
        .null                                                                   // 4 filler
    ])

    private let fixTransformer = FixedWidthTransformer([
        .recordType,                                                            // 0 record type
        .string(),                                                              // 1 id
        .generic({ try raw($0, toEnum: Navaid.FacilityType.self) }),            // 2 facility type

            .generic({ $0.split(separator: "*").first }),                           // 3 first fix
        .fixedWidthArray(width: 36, convert: { $0.split(separator: "*").first }, nullable: .blank), // 4 other fixes
        .null                                                                   // 5 blank
    ])

    private let holdingPatternTransformer = FixedWidthTransformer([
        .recordType,                                                            // 0 record type
        .string(),                                                              // 1 id
        .generic({ try raw($0, toEnum: Navaid.FacilityType.self) }),            // 2 facility type

            .string(),                                                              // 3 first pattern name
        .unsignedInteger(),                                                     // 4 first pattern number
        .fixedWidthArray(width: 83, convert: { try parseHoldingPattern($0, fieldIndex: 5) }, nullable: .blank), // 5 other patterns
        .null                                                                   // 6 blank
    ])

    private let fanMarkerTransformer = FixedWidthTransformer([
        .recordType,                                                            // 0 record type
        .string(),                                                              // 1 id
        .generic({ try raw($0, toEnum: Navaid.FacilityType.self) }),            // 2 facility type

            .string(),                                                              // 3 first fan marker
        .fixedWidthArray(width: 30, nullable: .blank),                          // 4 other fan markers
        .null                                                                   // 5 blank
    ])

    private let checkpointTransformer = FixedWidthTransformer([
        .recordType,                                                            //  0 record type
        .string(),                                                              //  1 id
        .generic({ try raw($0, toEnum: Navaid.FacilityType.self) }),            //  2 facility type

            .generic({ try raw($0, toEnum: VORCheckpoint.CheckpointType.self) }),   //  3 A/G code
        .unsignedInteger(),                                                     //  4 bearing
        .integer(nullable: .blank),                                             //  5 altitude
        .string(nullable: .blank),                                              //  6 airport code
        .string(),                                                              //  7 state code
        .string(nullable: .blank),                                              //  8 air desc
        .string(nullable: .blank),                                              //  9 gnd desc
        .null                                                                   // 10 blank
    ])

    func parseValues(_ values: Array<String>, for identifier: NavaidRecordIdentifier) throws {
        switch identifier {
            case .basicInfo: try parseBasicRecord(values)
            case .remark: try parseRemark(values)
            case .fixes: try parseFixes(values)
            case .holdingPatterns: try parseHoldingPatterns(values)
            case .fanMarkers: try parseFanMarkers(values)
            case .VORCheckpoint: try parseCheckpoint(values)
        }
    }

    func finish(data: NASRData) async {
        await data.finishParsing(navaids: Array(navaids.values))
    }

    private func parseBasicRecord(_ values: Array<String>) throws {
        let transformedValues = try basicTransformer.applyTo(values)

        let position = Location(latitude: transformedValues[22] as! Float,
                                longitude: transformedValues[24] as! Float,
                                elevation: transformedValues[31] as! Float?)
        var TACANPosition: Location? = nil
        if let lat = transformedValues[27] as? Float,
           let lon = transformedValues[29] as? Float {
            TACANPosition = Location(latitude: lat, longitude: lon, elevation: nil)
        }

        let navaid = Navaid(id: transformedValues[1] as! String,
                            name: transformedValues[5] as! String,
                            type: transformedValues[2] as! Navaid.FacilityType,
                            city: transformedValues[6] as! String,
                            stateName: transformedValues[7] as! String?,
                            FAARegion: transformedValues[9] as! String,
                            country: transformedValues[10] as! String?,
                            ownerName: transformedValues[12] as! String?,
                            operatorName: transformedValues[13] as! String?,
                            commonSystemUsage: transformedValues[14] as! Bool,
                            publicUse: transformedValues[15] as! Bool,
                            navaidClass: transformedValues[16] as! Navaid.NavaidClass?,
                            hoursOfOperation: transformedValues[17] as! String?,
                            highAltitudeARTCCCode: transformedValues[18] as! String?,
                            lowAltitudeARTCCCode: transformedValues[20] as! String?,
                            position: position,
                            TACANPosition: TACANPosition,
                            surveyAccuracy: transformedValues[26] as! Navaid.SurveyAccuracy?,
                            magneticVariation: transformedValues[32] as! Int?,
                            magneticVariationEpoch: transformedValues[33] as! Date?,
                            simultaneousVoice: transformedValues[34] as! Bool?,
                            powerOutput: transformedValues[35] as! UInt?,
                            automaticVoiceID: transformedValues[36] as! Bool?,
                            monitoringCategory: transformedValues[37] as! Navaid.MonitoringCategory?,
                            radioVoiceCall: transformedValues[38] as! String?,
                            TACANChannel: transformedValues[39] as! Navaid.TACANChannel?,
                            frequency: transformedValues[40] as! UInt?,
                            beaconIdentifier: transformedValues[41] as! String?,
                            fanMarkerType: transformedValues[42] as! Navaid.FanMarkerType?,
                            fanMarkerMajorBearing: transformedValues[43] as! UInt?,
                            VORServiceVolume: transformedValues[44] as! Navaid.ServiceVolume?,
                            DMEServiceVolume: transformedValues[45] as! Navaid.ServiceVolume?,
                            lowAltitudeInHighStructure: transformedValues[46] as! Bool?,
                            ZMarkerAvailable: transformedValues[47] as! Bool?,
                            TWEBHours: transformedValues[48] as! String?,
                            TWEBPhone: transformedValues[49] as! String?,
                            controllingFSSCode: transformedValues[50] as! String?,
                            NOTAMAccountabilityCode: transformedValues[53] as! String?,
                            LFRLegs: transformedValues[54] as! Array<LFRLeg>?,
                            status: transformedValues[55] as! Navaid.Status,
                            pitchFlag: transformedValues[56] as! Bool,
                            catchFlag: transformedValues[57] as! Bool,
                            SUAFlag: transformedValues[58] as! Bool,
                            restrictionFlag: transformedValues[59] as! Bool?,
                            HIWASFlag: transformedValues[60] as! Bool?,
                            TWEBRestrictionFlag: transformedValues[61] as! Bool?)
        navaids[NavaidKey(navaid: navaid)] = navaid
    }

    private func parseRemark(_ values: Array<String>) throws {
        let transformedValues = try remarkTransformer.applyTo(values)
        try updateNavaid(transformedValues) { navaid in
            navaid.remarks.append(transformedValues[3] as! String)
        }
    }

    private func parseFixes(_ values: Array<String>) throws {
        let transformedValues = try fixTransformer.applyTo(values)
        try updateNavaid(transformedValues) { navaid in
            navaid.associatedFixNames.insert(String(transformedValues[3] as! Substring))
            if let otherFixes = transformedValues[4] as? Array<Substring> {
                for fix in otherFixes {
                    navaid.associatedFixNames.insert(String(fix))
                }
            }
        }
    }

    private func parseHoldingPatterns(_ values: Array<String>) throws {
        let transformedValues = try holdingPatternTransformer.applyTo(values)
        try updateNavaid(transformedValues) { navaid in
            let pattern = HoldingPatternID(name: transformedValues[3] as! String,
                                           number: transformedValues[4] as! UInt)
            navaid.associatedHoldingPatterns.insert(pattern)

            if let otherPatterns = transformedValues[5] as? Array<HoldingPatternID> {
                for pattern in otherPatterns {
                    navaid.associatedHoldingPatterns.insert(pattern)
                }
            }
        }
    }

    private func parseFanMarkers(_ values: Array<String>) throws {
        let transformedValues = try fanMarkerTransformer.applyTo(values)
        try updateNavaid(transformedValues) { navaid in
            navaid.fanMarkers.insert(transformedValues[3] as! String)
            if let otherMarkers = transformedValues[4] as? Array<String> {
                for fanMarker in otherMarkers {
                    navaid.fanMarkers.insert(fanMarker)
                }
            }
        }
    }

    private func parseCheckpoint(_ values: Array<String>) throws {
        let transformedValues = try checkpointTransformer.applyTo(values)
        try updateNavaid(transformedValues) { navaid in
            let checkpoint = VORCheckpoint(type: transformedValues[3] as! VORCheckpoint.CheckpointType,
                                           bearing: transformedValues[4] as! UInt,
                                           altitude: transformedValues[5] as! Int?,
                                           airportID: transformedValues[6] as! String?,
                                           stateCode: transformedValues[7] as! String,
                                           airDescription: transformedValues[8] as! String?,
                                           groundDescription: transformedValues[9] as! String?)
            navaid.checkpoints.append(checkpoint)
        }
    }

    private func updateNavaid(_ transformedValues: Array<Any?>, process: (inout Navaid) throws -> Void) throws {
        let ID: NavaidKey = NavaidKey(values: transformedValues)
        guard var navaid = navaids[ID] else {
            throw Error.unknownNavaid(transformedValues[1] as! String)
        }

        try process(&navaid)

        navaids[ID] = navaid
    }
}

fileprivate let classDesignatorDelimiters = CharacterSet(charactersIn: "-/")

fileprivate func parseClassDesignator(_ code: String) throws -> Navaid.NavaidClass {
    let scanner = Scanner(string: code)
    var navaidClass = Navaid.NavaidClass()

    for altCode in Navaid.NavaidClass.AltitudeCode.allCases {
        let altPrefix = "\(altCode.rawValue)-"
        if scanner.scanString(altPrefix) != nil {
            navaidClass.altitude = altCode
            break
        }
    }

isEmptyLoop:
    while !scanner.isAtEnd {
        _ = scanner.scanCharacters(from: classDesignatorDelimiters)

        let sortedCodes = Navaid.NavaidClass.ClassCode.allCases.sorted {
            $0.rawValue.count > $1.rawValue.count
        }
        for classCode in sortedCodes {
            if scanner.scanString(classCode.rawValue) != nil {
                navaidClass.codes.insert(classCode)
                continue isEmptyLoop
            }
        }

        if scanner.scanString("L") != nil {
            navaidClass.codes.insert(.NDBLowPower)
            continue
        } else if scanner.scanString("M") != nil {
            navaidClass.codes.insert(.NDBMediumPower)
            continue
        } else if scanner.scanString("H") != nil {
            navaidClass.codes.insert(.NDBHighPower)
            continue
        }

        // if we're still here, we never found something parseable
        if !scanner.isAtEnd {
            throw ParserError.unknownRecordEnumValue(code)
        }
    }

    return navaidClass
}

fileprivate func parseSurveyAccuracy(_ code: String) throws -> Navaid.SurveyAccuracy {
    switch code {
        case "0": return .unknown
        case "1": return .seconds(3600)
        case "2": return .seconds(600)
        case "3": return .seconds(60)
        case "4": return .seconds(10)
        case "5": return .seconds(1)
        case "6": return .NOS
        case "7": return .thirdOrderTriangulation
        default: throw ParserError.unknownRecordEnumValue(code)
    }
}

fileprivate func parseTACAN(_ string: String, fieldIndex: Int) throws -> Navaid.TACANChannel {
    let channelStr = string.prefix(upTo: string.index(before: string.endIndex))
    guard let channel = UInt8(channelStr) else {
        throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
    }

    switch string.last {
        case "X": return .init(channel: channel, band: .X)
        case "Y": return .init(channel: channel, band: .Y)
        default: throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
    }
}

fileprivate func parseServiceVolume(_ string: String) throws -> Navaid.ServiceVolume {
    switch string {
        case "H": return .high
        case "L": return .low
        case "T": return .terminal
        case "VH", "DH": return .navaidHigh
        case "VL", "DL": return .navaidLow
        default: throw ParserError.unknownRecordEnumValue(string)
    }
}

fileprivate func parseHoldingPattern(_ string: String, fieldIndex: Int) throws -> HoldingPatternID {
    let name = string.prefix(80).trimmingCharacters(in: .whitespaces)
    guard let number = UInt(string.suffix(3).trimmingCharacters(in: .whitespaces)) else {
        throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
    }
    return HoldingPatternID(name: name,
                            number: number)
}

fileprivate func parseLFRLegs(_ string: String, fieldIndex: Int) throws -> Array<LFRLeg> {
    let scanner = Scanner(string: string)
    var legs = Array<LFRLeg>()

    while !scanner.isAtEnd {
        guard let bearing = scanner.scanInt(),
              let quadrantChar = scanner.scanCharacter() else {
            throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
        }
        guard let quadrant = LFRLeg.Quadrant.for(String(quadrantChar)) else {
            throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
        }
        legs.append(.init(quadrant: quadrant, bearing: UInt(bearing)))
    }

    return legs
}
