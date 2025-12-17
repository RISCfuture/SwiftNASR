import Foundation

private var dateFormatter: DateFormatter {
  let df = DateFormatter()
  df.dateFormat = "dd MMM yyyy"
  df.locale = Locale(identifier: "en_US_POSIX")
  df.timeZone = zulu
  return df
}

private var lastUpdatedDateFormatter: DateFormatter {
  let df = DateFormatter()
  df.dateFormat = "dd MMM yyyy"
  df.locale = Locale(identifier: "en_US_POSIX")
  df.timeZone = zulu
  return df
}

class FixedWidthFSSParser: FixedWidthNoRecordIDParser {
  static let type: RecordType = .flightServiceStations
  var formats = [NASRTable]()

  var FSSes = [String: FSS]()

  private let frequencyParser = FrequencyParser()
  private let ddmmssParser = DDMMSSParser()

  private var transformer: FixedWidthTransformer {
    .init([
      .string(),  //  0 identifier
      .string(),  //  1 name
      .dateComponents(format: .dayMonthYear),  //  2 last updated
      .string(nullable: .blank),  //  3 associated airport site #
      .null,  //  4 airport name
      .null,  //  5 airport city
      .null,  //  6 airport state
      .null,  //  7 airport lat
      .null,  //  8 airport lon
      .generic { try Self.raw($0, toEnum: FSS.FSSType.self) },  //  9 facility type
      .string(nullable: .blank),  // 10 radio identifier
      .generic { try Self.raw($0, toEnum: FSS.Operator.self) },  // 11 owner code
      .string(nullable: .blank),  // 12 owner name
      .generic { try Self.raw($0, toEnum: FSS.Operator.self) },  // 13 operator code
      .string(nullable: .blank),  // 14 operator name
      .fixedWidthArray(
        width: 40,
        convert: { try self.frequencyParser.parse($0) },
        nullable: .compact
      ),  // 15 primary freqs
      .string(),  // 16 hours of operation
      .generic(
        { try Self.raw($0, toEnum: FSS.Status.self) },
        nullable: .blank
      ),  // 17 status
      .string(nullable: .blank),  // 18 name of nearest FSS with teletype capability
      .fixedWidthArray(
        width: 14,
        convert: { $0.split(separator: "*") },
        nullable: .compact
      ),  // 19 RCO identifications
      .fixedWidthArray(
        width: 7,
        convert: { $0.split(separator: "*") },
        nullable: .compact
      ),  // 20 associated navaids
      .null,  // 21 reserved
      .boolean(nullable: .blank),  // 22 wx radar availibility
      .boolean(),  // 23 EFAS availability
      .string(nullable: .blank),  // 24 flight watch hours of operation
      .string(nullable: .blank),  // 25 non-airport FSS city
      .string(nullable: .blank),  // 26 non-airport FSS state
      .DDMMSS(nullable: .blank),  // 27 non-airport FSS lat
      .DDMMSS(nullable: .blank),  // 28 non-airport FSS lon
      .string(nullable: .blank),  // 29 non-airport FSS region
      .null,  // 30 reserved
      .fixedWidthArray(
        width: 6,
        convert: { try self.frequencyParser.parse($0) },
        nullable: .compact
      ),  // 31 airport advisory freqs
      .fixedWidthArray(
        width: 6,
        convert: { try self.frequencyParser.parse($0) },
        nullable: .blank
      ),  // 32 VOLMET freqs
      .fixedWidthArray(width: 12, nullable: .blank),  // 33 VOLMET schedules of operation
      .string(nullable: .blank),  // 34 type of DF equipment
      .DDMMSS(nullable: .blank),  // 35 DF equipment lat
      .DDMMSS(nullable: .blank),  // 36 DF equipment lon
      .string(nullable: .blank),  // 37 low-alt enroute chart number
      .string(nullable: .blank),  // 38 telephone number
      .null,  // 39 reserved
      .delimitedArray(
        delimiter: "5F",
        convert: { String($0[$0.index($0.startIndex, offsetBy: 3)...]) },
        nullable: .compact
      ),  // 40 remarks
      .fixedWidthArray(width: 26, nullable: .blank),  // 41 comm facility city
      .fixedWidthArray(width: 20, nullable: .blank),  // 42 comm facility state
      .fixedWidthArray(
        width: 14,
        convert: { try self.ddmmssParser.parse($0) },
        nullable: .blank
      ),  // 43 comm facility lat
      .fixedWidthArray(
        width: 14,
        convert: { try self.ddmmssParser.parse($0) },
        nullable: .blank
      ),  // 44 comm facility lon
      .fixedWidthArray(
        width: 1,
        convert: { try Self.raw($0, toEnum: FSS.Operator.self) },
        nullable: .blank
      ),  // 45 comm facility owner code
      .fixedWidthArray(width: 69, nullable: .blank),  // 46 comm facility owner name
      .fixedWidthArray(
        width: 1,
        convert: { try Self.raw($0, toEnum: FSS.Operator.self) },
        nullable: .blank
      ),  // 47 comm facility operator code
      .fixedWidthArray(width: 69, nullable: .blank),  // 48 comm facility operator name
      .fixedWidthArray(width: 4, nullable: .blank),  // 49 comm facility FSS
      .fixedWidthArray(
        width: 9,
        convert: { try self.frequencyParser.parse($0) },
        nullable: .blank
      ),  // 50 comm facility frequency
      .fixedWidthArray(width: 20, nullable: .blank),  // 51 comm facility operational hours (local)
      .fixedWidthArray(
        width: 20,
        convert: { try Self.raw($0, toEnum: FSS.Status.self) },
        nullable: .blank
      ),  // 52 comm facility status
      .fixedWidthArray(
        width: 11,
        convert: { DateFormat.dayMonthYear.parse($0) },
        nullable: .blank
      ),  // 53 comm facility status date
      .fixedWidthArray(
        width: 7,
        convert: { $0.split(separator: "*") },
        nullable: .blank
      ),  // 54 navaid identifier & facility type
      .fixedWidthArray(width: 2, nullable: .blank),  // 55 comm facility low-alt enroute chart
      .fixedWidthArray(width: 2, nullable: .blank),  // 56 comm facility timezone
      .delimitedArray(delimiter: "5F", convert: { $0 }, nullable: .compact),  // 57 comm remarks
      .dateComponents(format: .monthDayYearSlash)  // 58 info extraction date
    ])
  }

  private let continuationTransformer = FixedWidthTransformer([
    .generic { $0[$0.startIndex..<$0.endIndex] },  // 0 record ID
    .fixedWidthArray(
      width: 14,
      convert: { $0.split(separator: "*") },
      nullable: .compact
    ),  // 1 RCO identifications
    .fixedWidthArray(
      width: 7,
      convert: { $0.split(separator: "*") },
      nullable: .compact
    ),  // 2 navaid identifier & facility type
    .delimitedArray(
      delimiter: "5F",
      convert: { $0 },
      nullable: .compact
    )  // 3 comm remarks
  ])

  private let asterisk = "*".utf8.first!

  // the format given by fss_rf.txt is all wrong
  var continuationFormat: NASRTable {
    let outlets = formats[1].fields[19]
    let navaids = formats[1].fields[20]
    let remarks = formats[1].fields[57]
    let fields = [
      NASRTableField(identifier: .databaseLocatorID, range: 0..<4),
      outlets, navaids, remarks
    ]
    return NASRTable(fields: fields)
  }

  private let facilityCount = 20  // TODO then why do some fields have cardinalities of 30 or 40?

  func parseValues(_ values: [String]) throws {
    if values.count == 4 {
      let transformedValues = try continuationTransformer.applyTo(values)
      try parseContinuation(transformedValues)
    } else {
      let transformedValues = try transformer.applyTo(values)
      try parseFSS(transformedValues)
    }
  }

  func formatForData(_ data: Data) throws -> NASRTable {
    if data[3] == asterisk { return continuationFormat }
    return formats[1]
  }

  func finish(data: NASRData) async {
    await data.finishParsing(FSSes: Array(FSSes.values))
  }

  private func parseFSS(_ transformedValues: [Any?]) throws {
    let ID = transformedValues[0] as! String

    var commFacilities = [FSS.CommFacility]()
    commFacilities.reserveCapacity(facilityCount)
    for i in 0..<facilityCount {
      guard let frequency = (transformedValues[50] as! [FSS.Frequency?])[i] else { continue }

      let city = (transformedValues[41] as! [String?])[i]
      let state = (transformedValues[42] as! [String?])[i]
      let lat = (transformedValues[43] as! [Float?])[i]
      let lon = (transformedValues[44] as! [Float?])[i]
      let owner = (transformedValues[45] as! [FSS.Operator?])[i]
      let ownerName = (transformedValues[46] as! [String?])[i]
      let `operator` = (transformedValues[47] as! [FSS.Operator?])[i]
      let operatorName = (transformedValues[48] as! [String?])[i]
      let hours = (transformedValues[51] as! [String?])[i]
      let status = (transformedValues[52] as! [FSS.Status?])[i]
      let statusDate = (transformedValues[53] as! [DateComponents?])[i]
      let navaidAndType = (transformedValues[54] as! [[Substring]?])[i]
      let chart = (transformedValues[55] as! [String?])[i]
      let timezone = (transformedValues[56] as! [String?])[i].flatMap {
        StandardTimeZone(rawValue: $0)
      }

      let location = zipOptionals(lat, lon).map { lat, lon in
        Location(latitude: lat, longitude: lon, elevation: nil)
      }

      let (navaid, navaidType) =
        try navaidAndType.map { navaidAndType in
          let navaid = String(navaidAndType[0])
          let typeString = String(navaidAndType[1])
          let navaidType = Navaid.FacilityType.for(typeString)
          guard navaidType != nil else {
            throw FixedWidthParserError.invalidValue(typeString, at: 54)
          }
          return (navaid, navaidType)
        } ?? (nil, nil) as (String?, Navaid.FacilityType?)

      let facility = FSS.CommFacility(
        frequency: frequency,
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
        navaidType: navaidType
      )
      commFacilities.append(facility)
    }

    let outlets = try (transformedValues[19] as! [[Substring]]).map { IDAndType -> FSS.Outlet in
      let type = try Self.raw(String(IDAndType[1]), toEnum: FSS.Outlet.OutletType.self)
      return FSS.Outlet(
        identification: String(IDAndType[0]),
        type: type
      )
    }

    let navaids = (transformedValues[20] as! [[Substring]]).map { IDAndType -> FSS.Navaid in
      return FSS.Navaid(
        identification: String(IDAndType[0]),
        type: Navaid.FacilityType.for(String(IDAndType[1]))!
      )
    }

    let VOLMETCount = (transformedValues[32] as! [Any]).count
    var VOLMETs = [FSS.VOLMET]()
    VOLMETs.reserveCapacity(VOLMETCount)
    for (i, frequency) in (transformedValues[32] as! [FSS.Frequency?]).enumerated() {
      guard let frequency else { continue }
      let schedule = (transformedValues[33] as! [String?])[i]
      VOLMETs.append(FSS.VOLMET(frequency: frequency, schedule: schedule!))
    }

    let DFEquipment = (transformedValues[34] as! String?).map { type in
      FSS.DirectionFindingEquipment(
        type: type,
        location: Location(
          latitude: transformedValues[35] as! Float,
          longitude: transformedValues[36] as! Float,
          elevation: nil
        )
      )
    }

    let location = zipOptionals(transformedValues[27], transformedValues[28]).map { lat, lon in
      Location(
        latitude: lat as! Float,
        longitude: lon as! Float,
        elevation: nil
      )
    }

    let commRemarks = (transformedValues[57] as! [String])
      .map { String($0[$0.index($0.startIndex, offsetBy: 4)...]) }

    let fss = FSS(
      id: ID,
      airportId: transformedValues[3] as! String?,
      name: transformedValues[1] as! String,
      radioIdentifier: transformedValues[10] as! String?,
      type: transformedValues[9] as! FSS.FSSType,
      hoursOfOperation: transformedValues[16] as! String,
      status: transformedValues[17] as! FSS.Status?,
      lowAltEnrouteChartNumber: transformedValues[36] as! String?,
      frequencies: transformedValues[15] as! [FSS.Frequency],
      commFacilities: commFacilities,
      outlets: outlets,
      navaids: navaids,
      airportAdvisoryFrequencies: transformedValues[31] as! [FSS.Frequency],
      VOLMETs: VOLMETs,
      owner: transformedValues[11] as! FSS.Operator?,
      ownerName: transformedValues[12] as! String?,
      operator: transformedValues[13] as! FSS.Operator,
      operatorName: transformedValues[14] as! String?,
      hasWeatherRadar: transformedValues[22] as! Bool?,
      hasEFAS: transformedValues[23] as? Bool,
      flightWatchAvailability: transformedValues[24] as! String?,
      nearestFSSIdWithTeletype: transformedValues[18] as! String?,
      city: transformedValues[25] as! String?,
      stateName: transformedValues[26] as! String?,
      region: transformedValues[29] as! String?,
      location: location,
      DFEquipment: DFEquipment,
      phoneNumber: transformedValues[38] as! String?,
      remarks: transformedValues[40] as! [String],
      commRemarks: commRemarks
    )
    FSSes[ID] = fss
  }

  private func parseContinuation(_ transformedValues: [Any?]) throws {
    try updateFSS(transformedValues) { fss in
      for IDAndType in transformedValues[1] as! [[Substring]] {
        let type = try Self.raw(String(IDAndType[1]), toEnum: FSS.Outlet.OutletType.self)
        fss.outlets.append(
          FSS.Outlet(
            identification: String(IDAndType[0]),
            type: type
          )
        )
      }

      for IDAndType in transformedValues[2] as! [[Substring]] {
        let navaid = String(IDAndType[0])
        let typeString = String(IDAndType[1])
        guard let navaidType = Navaid.FacilityType.for(typeString) else {
          throw FixedWidthParserError.invalidValue(typeString, at: 54)
        }
        fss.navaids.append(
          FSS.Navaid(
            identification: navaid,
            type: navaidType
          )
        )
      }

      fss.remarks.append(contentsOf: (transformedValues[3] as! [String]))
    }
  }

  private func updateFSS(_ transformedValues: [Any?], process: (inout FSS) throws -> Void) throws {
    let IDAndStar = transformedValues[0] as! Substring
    let ID = String(IDAndStar[IDAndStar.startIndex..<IDAndStar.index(before: IDAndStar.endIndex)])
    guard var fss = FSSes[ID] else { throw Error.unknownFSS(ID) }

    try process(&fss)

    FSSes[ID] = fss
  }
}
