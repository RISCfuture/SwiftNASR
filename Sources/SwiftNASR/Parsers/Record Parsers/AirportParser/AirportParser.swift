import Foundation

enum AirportRecordIdentifier: String {
  case airport = "APT"
  case attendanceSchedule = "ATT"
  case runway = "RWY"
  case runwayArrestingSystem = "ARS"
  case remark = "RMK"
}

actor FixedWidthAirportParser: FixedWidthParser {
  typealias RecordIdentifier = AirportRecordIdentifier

  static let type: RecordType = .airports
  static let layoutFormatOrder: [RecordIdentifier] = [
    .airport, .attendanceSchedule, .runway, .runwayArrestingSystem, .remark
  ]
  var formats = [NASRTable]()

  var airports = [String: Airport]()

  // MARK: - Transformers

  private let airportTransformer = ByteTransformer([
    .recordType,  //   0 record type
    .string(),  //   1 site number
    .recordEnum(Airport.FacilityType.self),  //   2 facility type
    .string(),  //   3 LID
    .null,  //   4 effective date

    .recordEnum(Airport.FAARegion.self, nullable: .blank),  //   5 region code
    .string(nullable: .sentinel(["NONE"])),  //   6 field office code
    .string(nullable: .blank),  //   7 state post office code
    .null,  //   8 state name
    .string(),  //   9 county name
    .string(),  //  10 county state post office code
    .string(),  //  11 city
    .string(),  //  12 airport name

    .recordEnum(Airport.Ownership.self),  //  13 ownership type
    .boolean(trueValue: "PU"),  //  14 facility use
    .string(nullable: .blank),  //  15 owner's name
    .string(nullable: .blank),  //  16 owner's address
    .string(nullable: .blank),  //  17 owner's city state zip
    .string(nullable: .blank),  //  18 owner's phone
    .string(nullable: .blank),  //  19 manager's name
    .string(nullable: .blank),  //  20 manager's address
    .string(nullable: .blank),  //  21 manager's city state zip
    .string(nullable: .blank),  //  22 manager's phone

    .DDMMSS(),  //  23 lat - formatted
    .null,  //  24 lat - decimal
    .DDMMSS(),  //  25 lon - formatted
    .null,  //  26 lon - decimal
    .recordEnum(SurveyMethod.self),  // 27 ARP determination method
    .float(),  //  28 elevation
    .recordEnum(SurveyMethod.self, nullable: .blank),  //  29 elevation determination method
    .generic({ try parseMagVar($0, fieldIndex: 30) }, nullable: .blank),  //  30 magvar
    .dateComponents(format: .yearOnly, nullable: .blank),  //  31 magvar epoch
    .integer(nullable: .blank),  //  32 TPA
    .string(nullable: .blank),  //  33 sectional
    .unsignedInteger(nullable: .blank),  //  34 distance to city
    .recordEnum(Direction.self, nullable: .blank),  //  35 direction city -> airport
    .float(nullable: .blank),  //  36 land area

    .string(),  //  37 ARTCC ID
    .null,  //  38 ARTCC computer ID
    .null,  //  39 ARTCC name
    .string(),  //  40 responsible ARTCC ID
    .null,  //  41 responsible ARTCC computer ID
    .null,  //  42 responsible ARTCC name
    .boolean(nullable: .blank),  //  43 tie-in FSS on field
    .string(),  //  44 tie-in FSS ID
    .string(),  //  45 tie-in FSS name
    .null,  //  46 local FSS number
    .null,  //  47 toll-free FSS number
    .string(nullable: .blank),  //  48 alternate FSS ID
    .null,  //  49 alternate FSS name
    .null,  //  60 alternate FSS toll-free number
    .string(nullable: .blank),  //  51 NOTAM faclity ID
    .boolean(nullable: .blank),  //  52 NOTAM D available

    .dateComponents(format: .monthYear, nullable: .blank),  //  53 activation date
    .generic { Airport.Status(rawValue: $0) },  //  54 status code
    .delimitedArray(
      delimiter: " ",
      convert: { $0 },
      nullable: .compact,
      emptyPlaceholders: ["BLANK"]
    ),  //  55 ARFF certification type and date
    .fixedWidthArray(
      convert: { try Airport.FederalAgreement.require($0) },
      nullable: .compact,
      emptyPlaceholders: ["NONE", "BLANK"]
    ),  //  56 federal agreements code
    .recordEnum(Airport.AirspaceAnalysisDetermination.self, nullable: .blank),  //  57 airspace analysis determination
    .boolean(nullable: .blank),  //  58 airport of entry
    .boolean(nullable: .blank),  //  59 customs airport
    .boolean(nullable: .blank),  //  60 joint use
    .boolean(nullable: .blank),  //  61 military landing rights

    .recordEnum(Airport.InspectionMethod.self, nullable: .blank),  //  62 inspection method
    .recordEnum(Airport.InspectionAgency.self, nullable: .blank),  //  63 inspection agency
    .dateComponents(
      format: .monthDayYear,
      nullable: .blank
    ),  //  64 last inspection date
    .dateComponents(
      format: .monthDayYear,
      nullable: .blank
    ),  //  65 last information request completed date

    .fixedWidthArray(
      width: 5,
      convert: { Airport.FuelType(rawValue: $0) },
      nullable: .compact
    ),  //  66 available fuel types
    .recordEnum(Airport.RepairService.self, nullable: .blank),  //  67 airframe repair available
    .recordEnum(Airport.RepairService.self, nullable: .blank),  //  68 powerplant repair available
    .delimitedArray(
      delimiter: "/",
      convert: { try Airport.OxygenPressure.require($0) },
      nullable: .compact,
      emptyPlaceholders: ["NONE"]
    ),  //  69 bottled oxygen available
    .delimitedArray(
      delimiter: "/",
      convert: { try Airport.OxygenPressure.require($0) },
      nullable: .compact,
      emptyPlaceholders: ["NONE"]
    ),  //  70 bulk oxygen available

    .string(nullable: .blank),  //  71 airport lighting schedule
    .string(nullable: .blank),  //  72 beacon lighting schedule
    .boolean(),  //  73 has control tower
    .frequency(nullable: .blank),  //  74 UNICOM
    .frequency(nullable: .blank),  //  75 CTAF
    .generic(
      { segCir in
        segCir == "NONE"
          ? Airport.AirportMarker.none : try Airport.AirportMarker.require(segCir)
      },
      nullable: .blank
    ),  //  76 segmented circle
    .recordEnum(Airport.LensColor.self, nullable: .blank),  //  77 beacon color
    .boolean(nullable: .blank),  //  78 landing fee
    .boolean(nullable: .blank),  //  79 medical use

    .unsignedInteger(nullable: .blank),  //  80 GA singles
    .unsignedInteger(nullable: .blank),  //  81 GA twins
    .unsignedInteger(nullable: .blank),  //  82 GA jets
    .unsignedInteger(nullable: .blank),  //  83 GA helis
    .unsignedInteger(nullable: .blank),  //  84 gliders
    .unsignedInteger(nullable: .blank),  //  85 military aircraft
    .unsignedInteger(nullable: .blank),  //  86 ultralights

    .unsignedInteger(nullable: .blank),  //  87 commercial ops
    .unsignedInteger(nullable: .blank),  //  88 commuter ops
    .unsignedInteger(nullable: .blank),  //  89 air taxi ops
    .unsignedInteger(nullable: .blank),  //  90 GA local ops
    .unsignedInteger(nullable: .blank),  //  91 GA transient ops
    .unsignedInteger(nullable: .blank),  //  92 military ops
    .dateComponents(
      format: .monthDayYearSlash,
      nullable: .blank
    ),  //  93 ops 12-month period end date

    .string(nullable: .blank),  //  94 position source
    .dateComponents(
      format: .monthDayYearSlash,
      nullable: .blank
    ),  //  95 position source date
    .string(nullable: .blank),  //  96 elevation source
    .dateComponents(
      format: .monthDayYearSlash,
      nullable: .blank
    ),  //  97 elevation source date
    .boolean(nullable: .blank),  //  98 contract fuel available
    .delimitedArray(
      delimiter: ",",
      convert: { try Airport.StorageFacility.require($0) },
      nullable: .compact
    ),  // 99 transient storage facilities
    .delimitedArray(
      delimiter: ",",
      convert: { try Airport.Service.require($0) },
      nullable: .compact
    ),  // 100 other services
    .recordEnum(Airport.AirportMarker.self, nullable: .blank),  // 101 wind indicator
    .string(nullable: .blank),  // 102 ICAO code
    .boolean(),  // 103 MON
    .null  // 104 blank
  ])

  // MARK: - Parsers

  func parseValues(_ values: [ArraySlice<UInt8>], for identifier: AirportRecordIdentifier) throws {
    switch identifier {
      case .airport:
        try parseAirportRecord(values)
      case .attendanceSchedule:
        try parseAttendanceRecord(values)
      case .remark:
        try parseRemarkRecord(values)
      case .runway:
        try parseRunwayRecord(values)
      case .runwayArrestingSystem:
        try parseArrestingSystemRecord(values)
    }
  }

  private func parseAirportRecord(_ values: [ArraySlice<UInt8>]) throws {
    let t = try airportTransformer.applyTo(values)

    let owner = try parsePerson(t: t, startIndex: 15),
      manager = try parsePerson(t: t, startIndex: 19)

    let ARFFStrings: [String] = try t[55],
      ARFFCapability = try ARFFStrings.presence.map { ARFFString in
        guard let ARFFClass = Airport.ARFFCapability.Class(rawValue: ARFFString[0]) else {
          throw FixedWidthParserError.invalidValue(ARFFString[0], at: 55)
        }
        guard let ARFFIndex = Airport.ARFFCapability.Index(rawValue: ARFFString[1]) else {
          throw FixedWidthParserError.invalidValue(ARFFString[1], at: 55)
        }
        guard let ARFFService = Airport.ARFFCapability.AirService(rawValue: ARFFString[2]) else {
          throw FixedWidthParserError.invalidValue(ARFFString[2], at: 55)
        }
        guard let ARFFDateComponents = DateFormat.monthYear.parse(ARFFString[3]) else {
          throw FixedWidthParserError.invalidValue(ARFFString[3], at: 55)
        }
        return Airport.ARFFCapability(
          class: ARFFClass,
          index: ARFFIndex,
          airService: ARFFService,
          certificationDateComponents: ARFFDateComponents
        )
      }

    let lat: Float = try t[23],
      lon: Float = try t[25],
      elev: Float = try t[28],
      location = Location(latitudeArcsec: lat, longitudeArcsec: lon, elevationFtMSL: elev)

    let airport = Airport(
      id: try t[1],
      name: try t[12],
      LID: try t[3],
      ICAOIdentifier: try t[optional: 102],
      facilityType: try t[2],
      faaRegion: try t[optional: 5],
      FAAFieldOfficeCode: try t[optional: 6],
      stateCode: try t[optional: 7],
      county: try t[9],
      countyStateCode: try t[10],
      city: try t[11],
      ownership: try t[13],
      publicUse: try t[14],
      owner: owner,
      manager: manager,
      referencePoint: location,
      referencePointDeterminationMethod: try t[27],
      elevationDeterminationMethod: try t[optional: 29],
      magneticVariationDeg: try t[optional: 30],
      magneticVariationEpochComponents: try t[optional: 31],
      trafficPatternAltitudeFtAGL: try t[optional: 32],
      sectionalChart: try t[optional: 33],
      distanceCityToAirportNM: try t[optional: 34],
      directionCityToAirport: try t[optional: 35],
      landAreaAcres: try t[optional: 36],
      boundaryARTCCId: try t[optional: 37],
      responsibleARTCCId: try t[40],
      tieInFSSOnStation: try t[optional: 43],
      tieInFSSId: try t[44],
      alternateFSSId: try t[optional: 48],
      NOTAMIssuerId: try t[optional: 51],
      NOTAMDAvailable: try t[optional: 52],
      activationDateComponents: try t[optional: 53],
      status: try t[54],
      arffCapability: ARFFCapability,
      agreements: try t[56],
      airspaceAnalysisDetermination: try t[optional: 57],
      customsEntryAirport: try t[optional: 58],
      customsLandingRightsAirport: try t[optional: 59],
      jointUseAgreement: try t[optional: 60],
      militaryLandingRights: try t[optional: 61],
      inspectionMethod: try t[optional: 62],
      inspectionAgency: try t[optional: 63],
      lastPhysicalInspectionDateComponents: try t[optional: 64],
      lastInformationRequestCompletedDateComponents: try t[optional: 65],
      fuelsAvailable: try t[66],
      airframeRepairAvailable: try t[optional: 67],
      powerplantRepairAvailable: try t[optional: 68],
      bottledOxygenAvailable: try t[69],
      bulkOxygenAvailable: try t[70],
      airportLightingSchedule: try t[optional: 71],
      beaconLightingSchedule: try t[optional: 72],
      controlTower: try t[73],
      UNICOMFrequencyKHz: try t[optional: 74],
      CTAFKHz: try t[optional: 75],
      segmentedCircle: try t[optional: 76],
      beaconColor: try t[optional: 77],
      hasLandingFee: try t[optional: 78],
      medicalUse: try t[optional: 79],
      basedSingleEngineGA: try t[optional: 80],
      basedMultiEngineGA: try t[optional: 81],
      basedJetGA: try t[optional: 82],
      basedHelicopterGA: try t[optional: 83],
      basedOperationalGliders: try t[optional: 84],
      basedOperationalMilitary: try t[optional: 85],
      basedUltralights: try t[optional: 86],
      annualCommercialOps: try t[optional: 87],
      annualCommuterOps: try t[optional: 88],
      annualAirTaxiOps: try t[optional: 89],
      annualLocalGAOps: try t[optional: 90],
      annualTransientGAOps: try t[optional: 91],
      annualMilitaryOps: try t[optional: 92],
      annualPeriodEndDateComponents: try t[optional: 93],
      positionSource: try t[optional: 94],
      positionSourceDateComponents: try t[optional: 95],
      elevationSource: try t[optional: 96],
      elevationSourceDateComponents: try t[optional: 97],
      contractFuelAvailable: try t[optional: 98],
      transientStorageFacilities: try t[optional: 99],
      otherServices: try t[100],
      windIndicator: try t[optional: 101],
      minimumOperationalNetwork: try t[103]
    )

    airports[airport.id] = airport
  }

  func finish(data: NASRData) async {
    await data.finishParsing(airports: Array(airports.values))
  }

  // MARK: - Support Methods

  private func parsePerson(t: FixedWidthTransformedRow, startIndex: Int) throws -> Airport.Person? {
    guard let name: String = try t[optional: startIndex] else {
      return nil
    }
    let address1: String? = try t[optional: startIndex + 1],
      address2: String? = try t[optional: startIndex + 2]

    var phone: String? = try t[optional: startIndex + 3]
    if phone != nil {
      if phone!.starts(with: "1-") {
        phone = "1-800-\(phone![phone!.index(phone!.startIndex, offsetBy: 2)...])"
      } else if phone!.starts(with: "8-") {
        phone = "800-\(phone![phone!.index(phone!.startIndex, offsetBy: 2)...])"
      }
    }

    return Airport.Person(
      name: name,
      address1: address1,
      address2: address2,
      phone: phone
    )
  }
}
