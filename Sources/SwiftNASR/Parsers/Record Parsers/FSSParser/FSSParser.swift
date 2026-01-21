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

actor FixedWidthFSSParser: FixedWidthNoRecordIDParser {
  static let type: RecordType = .flightServiceStations
  var formats = [NASRTable]()

  var FSSes = [String: FSS]()

  private let frequencyParser = FrequencyParser()
  private let ddmmssParser = DDMMSSParser()

  private var transformer: ByteTransformer {
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
      .recordEnum(FSS.FSSType.self),  //  9 facility type
      .string(nullable: .blank),  // 10 radio identifier
      .recordEnum(FSS.Operator.self),  // 11 owner code
      .string(nullable: .blank),  // 12 owner name
      .recordEnum(FSS.Operator.self),  // 13 operator code
      .string(nullable: .blank),  // 14 operator name
      .fixedWidthArray(
        width: 40,
        convert: { try self.frequencyParser.parse($0) },
        nullable: .compact
      ),  // 15 primary freqs
      .string(),  // 16 hours of operation
      .recordEnum(FSS.Status.self, nullable: .blank),  // 17 status
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
        convert: { try FSS.Operator.require($0) },
        nullable: .blank
      ),  // 45 comm facility owner code
      .fixedWidthArray(width: 69, nullable: .blank),  // 46 comm facility owner name
      .fixedWidthArray(
        width: 1,
        convert: { try FSS.Operator.require($0) },
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
        convert: { try FSS.Status.require($0) },
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

  private let continuationTransformer = ByteTransformer([
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

  func parseValues(_ values: [ArraySlice<UInt8>]) throws {
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

  private func parseFSS(_ t: FixedWidthTransformedRow) throws {
    let ID: String = try t[0],
      frequencies50: [FSS.Frequency?] = try t[50],
      cities41: [String?] = try t[41],
      states42: [String?] = try t[42],
      lats43: [Float?] = try t[43],
      lons44: [Float?] = try t[44],
      owners45: [FSS.Operator?] = try t[45],
      ownerNames46: [String?] = try t[46],
      operators47: [FSS.Operator?] = try t[47],
      operatorNames48: [String?] = try t[48],
      hours51: [String?] = try t[51],
      statuses52: [FSS.Status?] = try t[52],
      statusDates53: [DateComponents?] = try t[53],
      navaidsAndTypes54: [[Substring]?] = try t[54],
      charts55: [String?] = try t[55],
      timezones56: [String?] = try t[56]

    var commFacilities = [FSS.CommFacility]()
    commFacilities.reserveCapacity(facilityCount)
    for i in 0..<facilityCount {
      guard let frequency = frequencies50[i] else { continue }

      let city = cities41[i],
        state = states42[i],
        lat = lats43[i],
        lon = lons44[i],
        owner = owners45[i],
        ownerName = ownerNames46[i],
        `operator` = operators47[i],
        operatorName = operatorNames48[i],
        hours = hours51[i],
        status = statuses52[i],
        statusDate = statusDates53[i],
        navaidAndType = navaidsAndTypes54[i],
        chart = charts55[i],
        timezone = timezones56[i].flatMap { StandardTimeZone(rawValue: $0) }

      let location = zipOptionals(lat, lon).map { lat, lon in
        Location(latitudeArcsec: lat, longitudeArcsec: lon, elevationFtMSL: nil)
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
        statusDateComponents: statusDate,
        navaid: navaid,
        navaidType: navaidType
      )
      commFacilities.append(facility)
    }

    let outletsRaw: [[Substring]] = try t[19],
      outlets = try outletsRaw.map { IDAndType -> FSS.Outlet in
        let type = try FSS.Outlet.OutletType.require(String(IDAndType[1]))
        return FSS.Outlet(identification: String(IDAndType[0]), type: type)
      }

    let navaidsRaw: [[Substring]] = try t[20],
      navaids = navaidsRaw.map { IDAndType -> FSS.Navaid in
        FSS.Navaid(
          identification: String(IDAndType[0]),
          type: Navaid.FacilityType.for(String(IDAndType[1]))!
        )
      }

    let VOLMETFreqs: [FSS.Frequency?] = try t[32],
      VOLMETSchedules: [String?] = try t[33]
    var VOLMETs = [FSS.VOLMET]()
    VOLMETs.reserveCapacity(VOLMETFreqs.count)
    for (i, frequency) in VOLMETFreqs.enumerated() {
      guard let frequency else { continue }
      let schedule = VOLMETSchedules[i]
      VOLMETs.append(FSS.VOLMET(frequency: frequency, schedule: schedule!))
    }

    let DFType: String? = try t[optional: 34],
      DFLat: Float? = try t[optional: 35],
      DFLon: Float? = try t[optional: 36],
      DFEquipment = DFType.map { type in
        FSS.DirectionFindingEquipment(
          type: type,
          location: Location(latitudeArcsec: DFLat!, longitudeArcsec: DFLon!)
        )
      }

    let lat27: Float? = try t[optional: 27],
      lon28: Float? = try t[optional: 28],
      location = zipOptionals(lat27, lon28).map { lat, lon in
        Location(latitudeArcsec: lat, longitudeArcsec: lon)
      }

    let commRemarksRaw: [String] = try t[57],
      commRemarks = commRemarksRaw.map { String($0[$0.index($0.startIndex, offsetBy: 4)...]) }

    let fss = FSS(
      id: ID,
      airportId: try t[optional: 3],
      name: try t[1],
      radioIdentifier: try t[optional: 10],
      type: try t[9],
      hoursOfOperation: try t[16],
      status: try t[optional: 17],
      lowAltEnrouteChartNumber: try t[optional: 37],
      frequencies: try t[15],
      commFacilities: commFacilities,
      outlets: outlets,
      navaids: navaids,
      airportAdvisoryFrequencies: try t[31],
      VOLMETs: VOLMETs,
      owner: try t[optional: 11],
      ownerName: try t[optional: 12],
      operator: try t[13],
      operatorName: try t[optional: 14],
      hasWeatherRadar: try t[optional: 22],
      hasEFAS: try t[optional: 23],
      flightWatchAvailability: try t[optional: 24],
      nearestFSSIdWithTeletype: try t[optional: 18],
      city: try t[optional: 25],
      stateName: try t[optional: 26],
      region: try t[optional: 29],
      location: location,
      DFEquipment: DFEquipment,
      phoneNumber: try t[optional: 38],
      remarks: try t[40],
      commRemarks: commRemarks
    )
    FSSes[ID] = fss
  }

  private func parseContinuation(_ t: FixedWidthTransformedRow) throws {
    let outletsRaw: [[Substring]] = try t[1],
      navaidsRaw: [[Substring]] = try t[2],
      remarksRaw: [String] = try t[3]

    try updateFSS(t) { fss in
      for IDAndType in outletsRaw {
        let type = try FSS.Outlet.OutletType.require(String(IDAndType[1]))
        fss.outlets.append(
          FSS.Outlet(identification: String(IDAndType[0]), type: type)
        )
      }

      for IDAndType in navaidsRaw {
        let navaid = String(IDAndType[0]),
          typeString = String(IDAndType[1])
        guard let navaidType = Navaid.FacilityType.for(typeString) else {
          throw FixedWidthParserError.invalidValue(typeString, at: 54)
        }
        fss.navaids.append(FSS.Navaid(identification: navaid, type: navaidType))
      }

      fss.remarks.append(contentsOf: remarksRaw)
    }
  }

  private func updateFSS(_ t: FixedWidthTransformedRow, process: (inout FSS) throws -> Void) throws
  {
    let IDAndStar: Substring = try t[0],
      ID = String(IDAndStar[IDAndStar.startIndex..<IDAndStar.index(before: IDAndStar.endIndex)])
    guard var fss = FSSes[ID] else { throw Error.unknownFSS(ID) }

    try process(&fss)

    FSSes[ID] = fss
  }
}
