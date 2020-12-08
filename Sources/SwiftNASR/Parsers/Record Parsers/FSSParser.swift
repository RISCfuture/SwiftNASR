import Foundation

fileprivate var dateFormatter: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "dd MMM yyyy"
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)
    return df
}

fileprivate var lastUpdatedDateFormatter: DateFormatter {
    let df = DateFormatter()
    df.dateFormat = "dd MMM yyyy"
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)
    return df
}

class FSSParser: FixedWidthNoRecordIDParser {
    static let type: RecordType = .flightServiceStations
    var formats = Array<NASRTable>()
    
    var FSSes = Dictionary<String, FSS>()

    private let transformer = FixedWidthTransformer([
        .string(),                                                              //  0 identifier
        .string(),                                                              //  1 name
        .datetime(formatter: lastUpdatedDateFormatter),                         //  2 last updated
        .string(nullable: .blank),                                              //  3 associated airport site #
        .null,                                                                  //  4 airport name
        .null,                                                                  //  5 airport city
        .null,                                                                  //  6 airport state
        .null,                                                                  //  7 airport lat
        .null,                                                                  //  8 airport lon
        .generic({ try FSSParser.raw($0, toEnum: FSS.FSSType.self) }),          //  9 facility type
        .string(nullable: .blank),                                              // 10 radio identifier
        .generic({ try FSSParser.raw($0, toEnum: FSS.Operator.self) }),         // 11 owner code
        .string(nullable: .blank),                                              // 12 owner name
        .generic({ try FSSParser.raw($0, toEnum: FSS.Operator.self) }),         // 13 operator code
        .string(nullable: .blank),                                              // 14 operator name
        .fixedWidthArray(width: 40,
                         convert: { try FSSParser.parseFrequency($0) },
                         nullable: .compact),                                   // 15 primary freqs
        .string(),                                                              // 16 hours of operation
        .generic({ try FSSParser.raw($0, toEnum: FSS.Status.self) },
                 nullable: .blank),                                             // 17 status
        .string(nullable: .blank),                                              // 18 name of nearest FSS with teletype capability
        .fixedWidthArray(width: 14,
                         convert: { $0.split(separator: "*") },
                         nullable: .compact),                                   // 19 RCO identifications
        .fixedWidthArray(width: 7,
                         convert: { $0.split(separator: "*") },
                         nullable: .compact),                                   // 20 associated navaids
        .null,                                                                  // 21 reserved
        .boolean(nullable: .blank),                                             // 22 wx radar availibility
        .boolean(),                                                             // 23 EFAS availability
        .string(nullable: .blank),                                              // 24 flight watch hours of operation
        .string(nullable: .blank),                                              // 25 non-airport FSS city
        .string(nullable: .blank),                                              // 26 non-airport FSS state
        .DDMMSS(nullable: .blank),                                              // 27 non-airport FSS lat
        .DDMMSS(nullable: .blank),                                              // 28 non-airport FSS lon
        .string(nullable: .blank),                                              // 29 non-airport FSS region
        .null,                                                                  // 30 reserved
        .fixedWidthArray(width: 6,
                         convert: { try FSSParser.parseFrequency($0) },
                         nullable: .compact),                                   // 31 airport advisory freqs
        .fixedWidthArray(width: 6,
                         convert: { try FSSParser.parseFrequency($0) },
                         nullable: .blank),                                     // 32 VOLMET freqs
        .fixedWidthArray(width: 12, nullable: .blank),                          // 33 VOLMET schedules of operation
        .string(nullable: .blank),                                              // 34 type of DF equipment
        .DDMMSS(nullable: .blank),                                              // 35 DF equipment lat
        .DDMMSS(nullable: .blank),                                              // 36 DF equipment lon
        .string(nullable: .blank),                                              // 37 low-alt enroute chart number
        .string(nullable: .blank),                                              // 38 telephone number
        .null,                                                                  // 39 reserved
        .delimitedArray(delimiter: "5F",
                        convert: { String($0[$0.index($0.startIndex, offsetBy: 3)...]) },
                        nullable: .compact), // 40 remarks
        .fixedWidthArray(width: 26, nullable: .blank),                          // 41 comm facility city
        .fixedWidthArray(width: 20, nullable: .blank),                          // 42 comm facility state
        .fixedWidthArray(width: 14,
                         convert: { FixedWidthTransformer.parseDDMMSS($0) },
                         nullable: .blank),                                     // 43 comm facility lat
        .fixedWidthArray(width: 14,
                         convert: { FixedWidthTransformer.parseDDMMSS($0) },
                         nullable: .blank),                                     // 44 comm facility lon
        .fixedWidthArray(width: 1,
                         convert: { try FSSParser.raw($0, toEnum: FSS.Operator.self) },
                         nullable: .blank),                                     // 45 comm facility owner code
        .fixedWidthArray(width: 69, nullable: .blank),                          // 46 comm facility owner name
        .fixedWidthArray(width: 1,
                         convert: { try FSSParser.raw($0, toEnum: FSS.Operator.self) },
                         nullable: .blank),                                     // 47 comm facility operator code
        .fixedWidthArray(width: 69, nullable: .blank),                          // 48 comm facility operator name
        .fixedWidthArray(width: 4, nullable: .blank),                           // 49 comm facility FSS
        .fixedWidthArray(width: 9,
                         convert: { try FSSParser.parseFrequency($0) },
                         nullable: .blank),                                     // 50 comm facility frequency
        .fixedWidthArray(width: 20, nullable: .blank),                          // 51 comm facility operational hours (local)
        .fixedWidthArray(width: 20,
                         convert: { try FSSParser.raw($0, toEnum: FSS.Status.self) },
                         nullable: .blank),                                     // 52 comm facility status
        .fixedWidthArray(width: 11,
                         convert: { lastUpdatedDateFormatter.date(from: $0) },
                         nullable: .blank),                                     // 53 comm facility status date
        .fixedWidthArray(width: 7, convert: { $0.split(separator: "*") },
                         nullable: .blank),                                     // 54 navaid identifier & facility type
        .fixedWidthArray(width: 2, nullable: .blank),                           // 55 comm facility low-alt enroute chart
        .fixedWidthArray(width: 2, nullable: .blank),                           // 56 comm facility timezone
        .delimitedArray(delimiter: "5F", convert: { $0 }, nullable: .compact),  // 57 comm remarks
        .datetime(formatter: FixedWidthTransformer.monthDayYearSlash)           // 58 info extraction date
    ])
    
    private let continuationTransformer =  FixedWidthTransformer([
        .generic({ $0[$0.startIndex..<$0.endIndex] }),                          // 0 record ID
        .fixedWidthArray(width: 14,
                         convert: { $0.split(separator: "*") },
                         nullable: .compact),                                   // 1 RCO identifications
        .fixedWidthArray(width: 7,
                         convert: { $0.split(separator: "*") },
                         nullable: .compact),                                   // 2 navaid identifier & facility type
        .delimitedArray(delimiter: "5F", convert: { $0 },
                        nullable: .compact)                                     // 3 comm remarks
    ])
    
    func parseValues(_ values: Array<String>) throws {
        if values.count == 4 {
            let transformedValues = try continuationTransformer.applyTo(values)
            try parseContinuation(transformedValues)
        } else {
            let transformedValues = try transformer.applyTo(values)
            try parseFSS(transformedValues)
        }
    }
    
    private let asterisk = "*".utf8.first!
    
    // the format given by fss_rf.txt is all wrong
    var continuationFormat: NASRTable {
        let outlets = formats[1].fields[19]
        let navaids = formats[1].fields[20]
        let remarks = formats[1].fields[57]
        let fields = [
            NASRTableField(identifier: .databaseLocatorID, range: 0..<4),
            outlets, navaids, remarks]
        return NASRTable(fields: fields)
    }
    
    func formatForData(_ data: Data) throws -> NASRTable {
        if data[3] == asterisk { return continuationFormat }
        else { return formats[1] }
    }
    
    func finish(data: NASRData) {
        data.FSSes = Array(FSSes.values)
    }
    
    private let facilityCount = 20 //TODO then why are do some fields have cardinalities of 30 or 40?
    
    private func parseFSS(_ transformedValues: Array<Any?>) throws {
        let ID = transformedValues[0] as! String
        
        var commFacilities = Array<FSS.CommFacility>()
        commFacilities.reserveCapacity(facilityCount)
        for i in 0..<facilityCount {
            guard let frequency = (transformedValues[50] as! Array<FSS.Frequency?>)[i] else { continue }

            let city = (transformedValues[41] as! Array<String?>)[i]
            let state = (transformedValues[42] as! Array<String?>)[i]
            let lat = (transformedValues[43] as! Array<Float?>)[i]
            let lon = (transformedValues[44] as! Array<Float?>)[i]
            let owner = (transformedValues[45] as! Array<FSS.Operator?>)[i]
            let ownerName = (transformedValues[46] as! Array<String?>)[i]
            let `operator` = (transformedValues[47] as! Array<FSS.Operator?>)[i]
            let operatorName = (transformedValues[48] as! Array<String?>)[i]
            let hours = (transformedValues[51] as! Array<String?>)[i]
            let status = (transformedValues[52] as! Array<FSS.Status?>)[i]
            let statusDate = (transformedValues[53] as! Array<Date?>)[i]
            let navaidAndType = (transformedValues[54] as! Array<Array<Substring>?>)[i]
            let chart = (transformedValues[55] as! Array<String?>)[i]
            let timezone = (transformedValues[56] as! Array<String?>)[i]
            
            var location: Location? = nil
            if lat != nil && lon != nil {
                location = Location(latitude: lat!, longitude: lon!, elevation: nil)
            }
            
            var navaid: String? = nil
            var navaidType: NavaidFacilityType? = nil
            if navaidAndType != nil {
                navaid = String(navaidAndType![0])
                let typeString = String(navaidAndType![1])
                navaidType = NavaidFacilityType(rawValue: typeString)
                guard navaidType != nil else {
                    throw FixedWidthParserError.invalidValue(typeString, at: 54)
                }
            }
            
            let facility = FSS.CommFacility(frequency: frequency,
                                            operationalHours: hours,
                                            city: city,
                                            stateName: state,
                                            location: location,
                                            lowAltEnrouteChart: chart,
                                            timezone: timezone,
                                            owner: owner,
                                            ownerName: ownerName,
                                            operator: `operator`,
                                            operatorName: operatorName,
                                            status: status,
                                            statusDate: statusDate,
                                            navaid: navaid,
                                            navaidType: navaidType)
            commFacilities.append(facility)
        }
        
        let outlets = try (transformedValues[19] as! Array<Array<Substring>>).map { IDAndType -> FSS.Outlet in
            let type = try Self.raw(String(IDAndType[1]), toEnum: FSS.Outlet.OutletType.self)
            return FSS.Outlet(identification: String(IDAndType[0]),
                              type: type)
        }
        
        let navaids = (transformedValues[20] as! Array<Array<Substring>>).map { IDAndType -> FSS.Navaid in
            return FSS.Navaid(identification: String(IDAndType[0]),
                              type: NavaidFacilityType(rawValue: String(IDAndType[1]))!)
        }
        
        let VOLMETCount = (transformedValues[32] as! Array<Any>).count
        var VOLMETs = Array<FSS.VOLMET>()
        VOLMETs.reserveCapacity(VOLMETCount)
        for (i, frequency) in (transformedValues[32] as! Array<FSS.Frequency?>).enumerated() {
            guard let frequency = frequency else { continue }
            let schedule = (transformedValues[33] as! Array<String?>)[i]
            VOLMETs.append(FSS.VOLMET(frequency: frequency, schedule: schedule!))
        }
        
        var DFEquipment: FSS.DirectionFindingEquipment? = nil
        if let DFType = (transformedValues[34] as! String?) {
            DFEquipment = FSS.DirectionFindingEquipment(
                type: DFType,
                location: Location(
                    latitude: transformedValues[35] as! Float,
                    longitude: transformedValues[36] as! Float,
                    elevation: nil))
        }
        
        var location: Location? = nil
        if transformedValues[27] != nil && transformedValues[28] != nil {
            location = Location(latitude: transformedValues[27] as! Float,
                                longitude: transformedValues[28] as! Float,
                                elevation: nil)
        }
        
        let commRemarks = (transformedValues[57] as! Array<String>)
            .map { String($0[$0.index($0.startIndex, offsetBy: 4)...]) }

        let fss = FSS(ID: ID,
                      airportID: transformedValues[3] as! String?,
                      name: transformedValues[1] as! String,
                      radioIdentifier: transformedValues[10] as! String?,
                      type: transformedValues[9] as! FSS.FSSType,
                      hoursOfOperation: transformedValues[16] as! String,
                      status: transformedValues[17] as! FSS.Status?,
                      lowAltEnrouteChartNumber: transformedValues[36] as! String?,
                      frequencies: transformedValues[15] as! Array<FSS.Frequency>,
                      commFacilities: commFacilities,
                      outlets: outlets,
                      navaids: navaids,
                      airportAdvisoryFrequencies: transformedValues[31] as! Array<FSS.Frequency>,
                      VOLMETs: VOLMETs,
                      owner: transformedValues[11] as! FSS.Operator?,
                      ownerName: transformedValues[12] as! String?,
                      operator: transformedValues[13] as! FSS.Operator,
                      operatorName: transformedValues[14] as! String?,
                      hasWeatherRadar: transformedValues[22] as! Bool?,
                      hasEFAS: transformedValues[23] as! Bool,
                      flightWatchAvailability: transformedValues[24] as! String?,
                      nearestFSSIDWithTeletype: transformedValues[18] as! String?,
                      city: transformedValues[25] as! String?,
                      stateName: transformedValues[26] as! String?,
                      region: transformedValues[29] as! String?,
                      location: location,
                      DFEquipment: DFEquipment,
                      phoneNumber: transformedValues[38] as! String?,
                      remarks: transformedValues[40] as! Array<String>,
                      commRemarks: commRemarks)
        FSSes[ID] = fss
    }
    
    private func parseContinuation(_ transformedValues: Array<Any?>) throws {
        let IDAndStar = transformedValues[0] as! Substring
        let ID = String(IDAndStar[IDAndStar.startIndex..<IDAndStar.index(before: IDAndStar.endIndex)])
        guard let fss = FSSes[ID] else { throw Error.unknownFSS(ID) }
        
        for IDAndType in transformedValues[1] as! Array<Array<Substring>> {
            let type = try Self.raw(String(IDAndType[1]), toEnum: FSS.Outlet.OutletType.self)
            fss.outlets.append(FSS.Outlet(identification: String(IDAndType[0]),
                                          type: type))
        }
        
        for IDAndType in transformedValues[2] as! Array<Array<Substring>> {
            let navaid = String(IDAndType[0])
            let typeString = String(IDAndType[1])
            guard let navaidType = NavaidFacilityType(rawValue: typeString) else {
                throw FixedWidthParserError.invalidValue(typeString, at: 54)
            }
            fss.navaids.append(FSS.Navaid(identification: navaid,
                                          type: navaidType))
        }
        
        fss.remarks.append(contentsOf: (transformedValues[3] as! Array<String>))
    }

    private static let frequencyPattern = #"^(\d+)(?:\.(\d+))?([TRX]?)(\(SSB\))?(?: (.+))?$"#
    private static var frequencyRegex: NSRegularExpression { try! NSRegularExpression(pattern: frequencyPattern, options: []) }

    private static func parseFrequency(_ string: String) throws -> FSS.Frequency {
        guard let matches = frequencyRegex.firstMatch(in: string, options: .anchored, range: string.nsRange) else {
            throw Error.invalidFrequency(string)
        }

        guard let decimalRange = Range(matches.range(at: 1), in: string) else {
            throw Error.invalidFrequency(string)
        }
        var frequency = UInt(string[decimalRange])!

        if let fractionalRange = Range(matches.range(at: 2), in: string) {
            let fractional = string[fractionalRange].padding(toLength: 3, withPad: "0", startingAt: 0)
            frequency = frequency * 1000 + UInt(fractional)!
        }

        let useRange = Range(matches.range(at: 3), in: string)
        let useString = useRange != nil ? String(string[useRange!]) : nil
        let use = useString != nil ? FSS.Frequency.Use(rawValue: useString!) : nil
        let SSBRange = Range(matches.range(at: 4), in: string)
        let nameRange = Range(matches.range(at: 5), in: string)
        let name = nameRange != nil ? String(string[nameRange!]) : nil

        return FSS.Frequency(frequency: frequency,
                             name: name,
                             singleSideband: SSBRange != nil,
                             use: use)
    }

    enum Error: Swift.Error, CustomStringConvertible {
        case invalidFrequency(_ string: String)
        case unknownFSS(_ ID: String)
        
        public var description: String {
            switch self {
                case .invalidFrequency(let string):
                    return "Invalid frequency '\(string)'"
                case .unknownFSS(let ID):
                    return "Continuation record references unknown FSS '\(ID)'"
            }
        }
    }
}
