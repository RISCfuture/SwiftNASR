import Foundation
import StreamingCSV
import ZIPFoundation

/// CSV Airport Parser using declarative transformers like FixedWidthAirportParser
class CSVAirportParser: CSVParser {
  var csvDirectory = URL(fileURLWithPath: "/")

  var airports = [String: Airport]()

  // MARK: - Transformers (matching FixedWidthAirportParser field types exactly)

  private let airportTransformer = CSVTransformer([
    .null,  //   0 effective date (skip for now)
    .string(),  //   1 site number
    .generic { try ParserHelpers.parseAirportFacilityType($0) },  //   2 facility type (CSV uses codes)
    .string(),  //   3 LID (ARPT_ID in CSV)
    .null,  //   4 skip state code in this position

    .generic(
      { try raw($0, toEnum: Airport.FAARegion.self) },
      nullable: .blank
    ),  //   5 region code
    .string(nullable: .sentinel(["NONE"])),  //   6 field office code
    .string(nullable: .blank),  //   7 state post office code
    .null,  //   8 state name
    .string(),  //   9 county name
    .string(),  //  10 county state post office code
    .string(),  //  11 city
    .string(),  //  12 airport name

    .generic { try raw($0, toEnum: Airport.Ownership.self) },  //  13 ownership type
    .boolean(trueValue: "PU"),  //  14 facility use
    .null,  //  15 owner's name (handled separately)
    .null,  //  16 owner's address (handled separately)
    .null,  //  17 owner's city state zip (handled separately)
    .null,  //  18 owner's phone (handled separately)
    .null,  //  19 manager's name (handled separately)
    .null,  //  20 manager's address (handled separately)
    .null,  //  21 manager's city state zip (handled separately)
    .null,  //  22 manager's phone (handled separately)

    .null,  //  23 lat - formatted (use decimal instead)
    .float(),  //  24 lat - decimal
    .null,  //  25 lon - formatted (use decimal instead)
    .float(),  //  26 lon - decimal
    .generic { try raw($0, toEnum: Airport.LocationDeterminationMethod.self) },  // 27 ARP determination method
    .float(),  //  28 elevation
    .generic(
      { try raw($0, toEnum: Airport.LocationDeterminationMethod.self) },
      nullable: .blank
    ),  //  29 elevation determination method
    .integer(nullable: .blank),  //  30 magvar (unsigned, sign from hemisphere)
    .string(nullable: .blank),  //  31 magvar hemisphere (W = negative, E = positive)
    .datetime(formatter: CSVTransformer.yearOnly, nullable: .blank),  //  32 magvar epoch
    .integer(nullable: .blank),  //  33 TPA
    .string(nullable: .blank),  //  34 sectional
    .unsignedInteger(nullable: .blank),  //  35 distance to city
    .generic(
      { return try raw($0, toEnum: Direction.self) },
      nullable: .blank
    ),  //  36 direction city -> airport
    .float(nullable: .blank),  //  37 land area

    .string(),  //  38 responsible ARTCC ID
    .string(),  //  39 boundary ARTCC computer ID
    .null,  //  40 ARTCC name
    .boolean(nullable: .blank),  //  41 tie-in FSS on field
    .string(),  //  42 tie-in FSS ID
    .null,  //  43 FSS name
    .null,  //  44 local phone
    .null,  //  45 toll-free phone
    .string(nullable: .blank),  //  46 alternate FSS ID
    .null,  //  47 alternate FSS name
    .null,  //  48 alternate toll-free number
    .string(nullable: .blank),  //  49 NOTAM facility ID
    .boolean(nullable: .blank),  //  50 NOTAM D available

    .datetime(formatter: CSVTransformer.yearMonthSlash, nullable: .blank),  //  51 activation date
    .generic { Airport.Status(rawValue: $0) },  //  52 status code
    .null,  //  53 FAR 139 type (skip for now)
    .null,  //  54 FAR 139 carrier service (skip for now)
    .delimitedArray(
      delimiter: " ",
      convert: { $0 },
      nullable: .compact,
      emptyPlaceholders: ["BLANK"]
    ),  //  55 ARFF certification type and date
    .fixedWidthArray(
      convert: { try raw($0, toEnum: Airport.FederalAgreement.self) },
      nullable: .compact,
      emptyPlaceholders: ["NONE", "BLANK"]
    ),  //  56 federal agreements code
    .generic(
      { try raw($0, toEnum: Airport.AirspaceAnalysisDetermination.self) },
      nullable: .blank
    ),  //  57 airspace analysis determination
    .boolean(nullable: .blank),  //  58 customs airport
    .boolean(nullable: .blank),  //  59 landing rights
    .boolean(nullable: .blank),  //  60 joint use
    .boolean(nullable: .blank),  //  61 military landing rights

    .generic(
      { try raw($0, toEnum: Airport.InspectionMethod.self) },
      nullable: .blank
    ),  //  62 inspection method
    .generic(
      { try raw($0, toEnum: Airport.InspectionAgency.self) },
      nullable: .blank
    ),  //  63 inspection agency
    .datetime(
      formatter: CSVTransformer.yearMonthDaySlash,
      nullable: .blank
    ),  //  64 last inspection date
    .datetime(
      formatter: CSVTransformer.yearMonthDaySlash,
      nullable: .blank
    ),  //  65 last information request completed date

    .fixedWidthArray(
      width: 5,
      convert: { Airport.FuelType(rawValue: $0) },
      nullable: .compact
    ),  //  66 available fuel types
    .generic(
      { try raw($0, toEnum: Airport.RepairService.self) },
      nullable: .blank
    ),  //  67 airframe repair available
    .generic(
      { try raw($0, toEnum: Airport.RepairService.self) },
      nullable: .blank
    ),  //  68 powerplant repair available
    .delimitedArray(
      delimiter: "/",
      convert: { try raw($0, toEnum: Airport.OxygenPressure.self) },
      nullable: .compact,
      emptyPlaceholders: ["NONE"]
    ),  //  69 bottled oxygen available
    .delimitedArray(
      delimiter: "/",
      convert: { try raw($0, toEnum: Airport.OxygenPressure.self) },
      nullable: .compact,
      emptyPlaceholders: ["NONE"]
    ),  //  70 bulk oxygen available

    .generic(
      { try raw($0, toEnum: Airport.LightingSchedule.self) },
      nullable: .blank
    ),  //  71 airport lighting schedule
    .generic(
      { try raw($0, toEnum: Airport.LightingSchedule.self) },
      nullable: .blank
    ),  //  72 beacon lighting schedule
    .null,  //  73 control tower (derived from TWR_TYPE_CODE)
    .generic(
      { try raw($0, toEnum: Airport.AirportMarker.self) },
      nullable: .blank
    ),  //  74 segmented circle
    .generic(
      { try raw($0, toEnum: Airport.LensColor.self) },
      nullable: .blank
    ),  //  75 beacon color
    .boolean(nullable: .blank),  //  76 landing fee
    .boolean(nullable: .blank),  //  77 medical use

    .string(nullable: .blank),  //  78 position source
    .datetime(
      formatter: CSVTransformer.yearMonthDaySlash,
      nullable: .blank
    ),  //  79 position source date
    .string(nullable: .blank),  //  80 elevation source
    .datetime(
      formatter: CSVTransformer.yearMonthDaySlash,
      nullable: .blank
    ),  //  81 elevation source date
    .boolean(nullable: .blank),  //  82 contract fuel available
    .boolean(nullable: .blank),  //  83 transient storage buoy
    .boolean(nullable: .blank),  //  84 transient storage hangar
    .boolean(nullable: .blank),  //  85 transient storage tie-down
    .delimitedArray(
      delimiter: ",",
      convert: { try raw($0, toEnum: Airport.Service.self) },
      nullable: .compact
    ),  //  86 other services
    .generic(
      { try raw($0, toEnum: Airport.AirportMarker.self) },
      nullable: .blank
    ),  //  87 wind indicator
    .string(nullable: .blank),  //  88 ICAO code
    .boolean(nullable: .blank)  //  89 MON (USER_FEE_FLAG in CSV, but treated as boolean for MON)
  ])

  // CSV field indices for APT_BASE.csv
  private let airportFieldIndices = [
    APTBaseField.EFF_DATE.rawValue,  //  0
    APTBaseField.SITE_NO.rawValue,  //  1
    APTBaseField.SITE_TYPE_CODE.rawValue,  //  2
    APTBaseField.ARPT_ID.rawValue,  //  3
    -1,  //  4 (no state code in this position)
    APTBaseField.REGION_CODE.rawValue,  //  5
    APTBaseField.ADO_CODE.rawValue,  //  6
    APTBaseField.STATE_CODE.rawValue,  //  7
    APTBaseField.STATE_NAME.rawValue,  //  8
    APTBaseField.COUNTY_NAME.rawValue,  //  9
    APTBaseField.COUNTY_ASSOC_STATE.rawValue,  // 10
    APTBaseField.CITY.rawValue,  // 11
    APTBaseField.ARPT_NAME.rawValue,  // 12
    APTBaseField.OWNERSHIP_TYPE_CODE.rawValue,  // 13
    APTBaseField.FACILITY_USE_CODE.rawValue,  // 14
    -1, -1, -1, -1,  // 15-18 owner fields (handled separately)
    -1, -1, -1, -1,  // 19-22 manager fields (handled separately)
    -1,  // 23 lat formatted (skip)
    APTBaseField.LAT_DECIMAL.rawValue,  // 24
    -1,  // 25 lon formatted (skip)
    APTBaseField.LONG_DECIMAL.rawValue,  // 26
    APTBaseField.SURVEY_METHOD_CODE.rawValue,  // 27
    APTBaseField.ELEV.rawValue,  // 28
    APTBaseField.ELEV_METHOD_CODE.rawValue,  // 29
    APTBaseField.MAG_VARN.rawValue,  // 30
    APTBaseField.MAG_HEMIS.rawValue,  // 31
    APTBaseField.MAG_VARN_YEAR.rawValue,  // 32
    APTBaseField.TPA.rawValue,  // 33
    APTBaseField.CHART_NAME.rawValue,  // 34
    APTBaseField.DIST_CITY_TO_AIRPORT.rawValue,  // 35
    APTBaseField.DIRECTION_CODE.rawValue,  // 36
    APTBaseField.ACREAGE.rawValue,  // 37
    APTBaseField.RESP_ARTCC_ID.rawValue,  // 38
    APTBaseField.COMPUTER_ID.rawValue,  // 39
    APTBaseField.ARTCC_NAME.rawValue,  // 40
    APTBaseField.FSS_ON_ARPT_FLAG.rawValue,  // 41
    APTBaseField.FSS_ID.rawValue,  // 42
    APTBaseField.FSS_NAME.rawValue,  // 43
    APTBaseField.PHONE_NO.rawValue,  // 44
    APTBaseField.TOLL_FREE_NO.rawValue,  // 45
    APTBaseField.ALT_FSS_ID.rawValue,  // 46
    APTBaseField.ALT_FSS_NAME.rawValue,  // 47
    APTBaseField.ALT_TOLL_FREE_NO.rawValue,  // 48
    APTBaseField.NOTAM_ID.rawValue,  // 49
    APTBaseField.NOTAM_FLAG.rawValue,  // 50
    APTBaseField.ACTIVATION_DATE.rawValue,  // 51
    APTBaseField.ARPT_STATUS.rawValue,  // 52
    APTBaseField.FAR_139_TYPE_CODE.rawValue,  // 53
    APTBaseField.FAR_139_CARRIER_SER_CODE.rawValue,  // 54
    APTBaseField.ARFF_CERT_TYPE_DATE.rawValue,  // 55
    APTBaseField.NASP_CODE.rawValue,  // 56
    APTBaseField.ASP_ANLYS_DTRM_CODE.rawValue,  // 57
    APTBaseField.CUST_FLAG.rawValue,  // 58
    APTBaseField.LNDG_RIGHTS_FLAG.rawValue,  // 59
    APTBaseField.JOINT_USE_FLAG.rawValue,  // 60
    APTBaseField.MIL_LNDG_FLAG.rawValue,  // 61
    APTBaseField.INSPECT_METHOD_CODE.rawValue,  // 62
    APTBaseField.INSPECTOR_CODE.rawValue,  // 63
    APTBaseField.LAST_INSPECTION.rawValue,  // 64
    APTBaseField.LAST_INFO_RESPONSE.rawValue,  // 65
    APTBaseField.FUEL_TYPES.rawValue,  // 66
    APTBaseField.AIRFRAME_REPAIR_SER_CODE.rawValue,  // 67
    APTBaseField.PWR_PLANT_REPAIR_SER.rawValue,  // 68
    APTBaseField.BOTTLED_OXY_TYPE.rawValue,  // 69
    APTBaseField.BULK_OXY_TYPE.rawValue,  // 70
    APTBaseField.LGT_SKED.rawValue,  // 71
    APTBaseField.BCN_LGT_SKED.rawValue,  // 72
    APTBaseField.TWR_TYPE_CODE.rawValue,  // 73 (used to determine control tower)
    APTBaseField.SEG_CIRCLE_MKR_FLAG.rawValue,  // 74
    APTBaseField.BCN_LENS_COLOR.rawValue,  // 75
    APTBaseField.LNDG_FEE_FLAG.rawValue,  // 76
    APTBaseField.MEDICAL_USE_FLAG.rawValue,  // 77
    APTBaseField.ARPT_PSN_SOURCE.rawValue,  // 78
    APTBaseField.POSITION_SRC_DATE.rawValue,  // 79
    APTBaseField.ARPT_ELEV_SOURCE.rawValue,  // 80
    APTBaseField.ELEVATION_SRC_DATE.rawValue,  // 81
    APTBaseField.CONTR_FUEL_AVBL.rawValue,  // 82
    APTBaseField.TRNS_STRG_BUOY_FLAG.rawValue,  // 83
    APTBaseField.TRNS_STRG_HGR_FLAG.rawValue,  // 84
    APTBaseField.TRNS_STRG_TIE_FLAG.rawValue,  // 85
    APTBaseField.OTHER_SERVICES.rawValue,  // 86
    APTBaseField.WIND_INDCR_FLAG.rawValue,  // 87
    APTBaseField.ICAO_ID.rawValue,  // 88
    APTBaseField.USER_FEE_FLAG.rawValue  // 89 (USER_FEE_FLAG used for MON boolean)
  ]

  // MARK: - Protocol Methods

  func prepare(distribution: Distribution) throws {
    // Set the CSV directory for CSV distributions
    if let dirDist = distribution as? DirectoryDistribution {
      csvDirectory = dirDist.location
    } else if let archiveDist = distribution as? ArchiveFileDistribution {
      // For downloaded CSV archives, extract to a temporary directory
      let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
        "SwiftNASR_CSV_\(UUID().uuidString)"
      )
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

      // Extract the archive to the temporary directory
      try FileManager.default.unzipItem(at: archiveDist.location, to: tempDir)
      csvDirectory = tempDir
    }
  }

  func parse(data _: Data) async throws {
    // 1. Parse base airport records
    try await parseCSVFile(filename: "APT_BASE.csv", expectedFieldCount: 90) { fields in
      try self.parseAirportRecord(fields)
    }

    // 2. Parse contacts (owner/manager info - must come before remarks)
    try await parseCSVFile(filename: "APT_CON.csv", expectedFieldCount: 16) { fields in
      try self.parseContactRecord(fields)
    }

    // 3. Parse runways
    try await parseCSVFile(filename: "APT_RWY.csv", expectedFieldCount: 25) { fields in
      try self.parseRunwayRecord(fields)
    }

    // 4. Parse runway ends
    try await parseCSVFile(filename: "APT_RWY_END.csv", expectedFieldCount: 80) { fields in
      try self.parseRunwayEndRecord(fields)
    }

    // 5. Parse arresting systems (requires runway ends to exist)
    try await parseCSVFile(filename: "APT_ARS.csv", expectedFieldCount: 10) { fields in
      try self.parseArrestingSystemRecord(fields)
    }

    // 6. Parse attendance schedules
    try await parseCSVFile(filename: "APT_ATT.csv", expectedFieldCount: 11) { fields in
      try self.parseAttendanceRecord(fields)
    }

    // 7. Parse remarks last (references runways/ends that must exist)
    try await parseCSVFile(filename: "APT_RMK.csv", expectedFieldCount: 13) { fields in
      try self.parseRemarkRecord(fields)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(airports: Array(airports.values))
  }

  // MARK: - Parsing Methods

  private func parseAirportRecord(_ values: [String]) throws {
    // Skip non-airport site types if needed
    let validSiteTypes = ["A", "H", "C", "B", "G", "U"]
    guard values.count > APTBaseField.SITE_TYPE_CODE.rawValue else {
      return
    }

    let siteType = values[APTBaseField.SITE_TYPE_CODE.rawValue]
    guard validSiteTypes.contains(siteType) else {
      return
    }

    let transformedValues = try airportTransformer.applyTo(values, indices: airportFieldIndices)

    // Handle special cases
    let location = Location(
      latitude: Float(values.doubleAt(APTBaseField.LAT_DECIMAL.rawValue) ?? 0) * 3600,  // Convert decimal degrees to arc-seconds
      longitude: Float(values.doubleAt(APTBaseField.LONG_DECIMAL.rawValue) ?? 0) * 3600,
      elevation: transformedValues[28] as? Float
    )

    // Parse ARFF if present
    let ARFFCapability = try parseARFFCapability(transformedValues[55] as? [String])

    // Handle control tower based on TWR_TYPE_CODE
    // NON-ATCT means no control tower
    let towerCode =
      values.count > APTBaseField.TWR_TYPE_CODE.rawValue
      ? values[APTBaseField.TWR_TYPE_CODE.rawValue]
      : ""
    let controlTower = !towerCode.isEmpty && !towerCode.hasPrefix("NON")

    // Compute magnetic variation with correct sign based on hemisphere
    // W (West) = negative, E (East) = positive
    let magneticVariation: Int? = {
      guard let magVar = transformedValues[30] as? Int else { return nil }
      let hemisphere = transformedValues[31] as? String ?? ""
      return hemisphere == "W" ? -magVar : magVar
    }()

    // Parse transient storage facilities
    var transientStorageFacilities: [Airport.StorageFacility] = []
    if transformedValues[83] as? Bool == true {
      transientStorageFacilities.append(.buoys)
    }
    if transformedValues[84] as? Bool == true {
      transientStorageFacilities.append(.hangars)
    }
    if transformedValues[85] as? Bool == true {
      transientStorageFacilities.append(.tiedowns)
    }

    let airport = Airport(
      id: transformedValues[1] as! String,
      name: transformedValues[12] as! String,
      LID: transformedValues[3] as! String,
      ICAOIdentifier: transformedValues[88] as? String,
      facilityType: transformedValues[2] as! Airport.FacilityType,
      FAARegion: transformedValues[5] as? Airport.FAARegion,
      FAAFieldOfficeCode: transformedValues[6] as? String,
      stateCode: transformedValues[7] as? String,
      county: transformedValues[9] as! String,
      countyStateCode: transformedValues[10] as! String,
      city: transformedValues[11] as! String,
      ownership: transformedValues[13] as! Airport.Ownership,
      publicUse: transformedValues[14] as! Bool,
      owner: nil,  // TODO: Parse owner info
      manager: nil,  // TODO: Parse manager info
      referencePoint: location,
      referencePointDeterminationMethod: transformedValues[27]
        as! Airport.LocationDeterminationMethod,
      elevationDeterminationMethod: transformedValues[29] as? Airport.LocationDeterminationMethod,
      magneticVariation: magneticVariation,
      magneticVariationEpoch: transformedValues[32] as? Date,
      trafficPatternAltitude: transformedValues[33] as? Int,
      sectionalChart: transformedValues[34] as? String,
      distanceCityToAirport: transformedValues[35] as? UInt,
      directionCityToAirport: transformedValues[36] as? Direction,
      landArea: transformedValues[37] as? Float,
      boundaryARTCCID: nil,  // Not available in CSV format
      responsibleARTCCID: transformedValues[38] as! String,
      tieInFSSOnStation: transformedValues[41] as? Bool,
      tieInFSSID: transformedValues[42] as! String,
      alternateFSSID: transformedValues[46] as? String,
      NOTAMIssuerID: transformedValues[49] as? String,
      NOTAMDAvailable: transformedValues[50] as? Bool,
      activationDate: transformedValues[51] as? Date,
      status: transformedValues[52] as! Airport.Status,
      ARFFCapability: ARFFCapability,
      agreements: (transformedValues[56] as? [Airport.FederalAgreement]) ?? [],
      airspaceAnalysisDetermination: transformedValues[57]
        as? Airport.AirspaceAnalysisDetermination,
      customsEntryAirport: transformedValues[58] as? Bool,
      customsLandingRightsAirport: transformedValues[59] as? Bool,
      jointUseAgreement: transformedValues[60] as? Bool,
      militaryLandingRights: transformedValues[61] as? Bool,
      inspectionMethod: transformedValues[62] as? Airport.InspectionMethod,
      inspectionAgency: transformedValues[63] as? Airport.InspectionAgency,
      lastPhysicalInspectionDate: transformedValues[64] as? Date,
      lastInformationRequestCompletedDate: transformedValues[65] as? Date,
      fuelsAvailable: (transformedValues[66] as? [Airport.FuelType]) ?? [],
      airframeRepairAvailable: transformedValues[67] as? Airport.RepairService,
      powerplantRepairAvailable: transformedValues[68] as? Airport.RepairService,
      bottledOxygenAvailable: (transformedValues[69] as? [Airport.OxygenPressure]) ?? [],
      bulkOxygenAvailable: (transformedValues[70] as? [Airport.OxygenPressure]) ?? [],
      airportLightingSchedule: transformedValues[71] as? Airport.LightingSchedule,
      beaconLightingSchedule: transformedValues[72] as? Airport.LightingSchedule,
      controlTower: controlTower,
      UNICOMFrequency: nil,  // TODO: Parse from separate file
      CTAF: nil,  // TODO: Parse from separate file
      segmentedCircle: transformedValues[74] as? Airport.AirportMarker,
      beaconColor: transformedValues[75] as? Airport.LensColor,
      landingFee: transformedValues[76] as? Bool,
      medicalUse: transformedValues[77] as? Bool,
      basedSingleEngineGA: nil,  // TODO: Parse from separate file
      basedMultiEngineGA: nil,  // TODO: Parse from separate file
      basedJetGA: nil,  // TODO: Parse from separate file
      basedHelicopterGA: nil,  // TODO: Parse from separate file
      basedOperationalGliders: nil,  // TODO: Parse from separate file
      basedOperationalMilitary: nil,  // TODO: Parse from separate file
      basedUltralights: nil,  // TODO: Parse from separate file
      annualCommercialOps: nil,  // TODO: Parse from separate file
      annualCommuterOps: nil,  // TODO: Parse from separate file
      annualAirTaxiOps: nil,  // TODO: Parse from separate file
      annualLocalGAOps: nil,  // TODO: Parse from separate file
      annualTransientGAOps: nil,  // TODO: Parse from separate file
      annualMilitaryOps: nil,  // TODO: Parse from separate file
      annualPeriodEndDate: nil,  // TODO: Parse from separate file
      positionSource: transformedValues[78] as? String,
      positionSourceDate: transformedValues[79] as? Date,
      elevationSource: transformedValues[80] as? String,
      elevationSourceDate: transformedValues[81] as? Date,
      contractFuelAvailable: transformedValues[82] as? Bool,
      transientStorageFacilities: transientStorageFacilities.presence,
      otherServices: (transformedValues[86] as? [Airport.Service]) ?? [],
      windIndicator: transformedValues[87] as? Airport.AirportMarker,
      minimumOperationalNetwork: (transformedValues[89] as? Bool) ?? false
    )

    // Use composite key of SITE_NO + SITE_TYPE_CODE to match TXT format
    // (TXT uses "23747.31*A" while CSV has separate fields)
    let siteTypeCode = values[APTBaseField.SITE_TYPE_CODE.rawValue]
    let compositeId = "\(airport.id)*\(siteTypeCode)"
    airports[compositeId] = airport
  }

  private func parseARFFCapability(_ ARFFString: [String]?) throws -> Airport.ARFFCapability? {
    guard let ARFFString, ARFFString.count >= 4 else { return nil }

    guard let ARFFClass = Airport.ARFFCapability.Class(rawValue: ARFFString[0]) else {
      throw CSVParserError.invalidValue(ARFFString[0], at: 55)
    }
    guard let ARFFIndex = Airport.ARFFCapability.Index(rawValue: ARFFString[1]) else {
      throw CSVParserError.invalidValue(ARFFString[1], at: 55)
    }
    guard let ARFFService = Airport.ARFFCapability.AirService(rawValue: ARFFString[2]) else {
      throw CSVParserError.invalidValue(ARFFString[2], at: 55)
    }
    guard let ARFFDate = CSVTransformer.monthYear.date(from: ARFFString[3]) else {
      throw CSVParserError.invalidValue(ARFFString[3], at: 55)
    }

    return Airport.ARFFCapability(
      class: ARFFClass,
      index: ARFFIndex,
      airService: ARFFService,
      certificationDate: ARFFDate
    )
  }

  // MARK: - Runway Parsing

  private func parseRunwayRecord(_ values: [String]) throws {
    let siteNo = values[APTRunwayField.SITE_NO.rawValue]
    let siteTypeCode = values[APTRunwayField.SITE_TYPE_CODE.rawValue]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard airports[compositeId] != nil else { return }

    let runwayId = values[APTRunwayField.RWY_ID.rawValue]
    let length = values.intAt(APTRunwayField.RWY_LEN.rawValue).map { UInt($0) }
    let width = values.intAt(APTRunwayField.RWY_WIDTH.rawValue).map { UInt($0) }

    // Parse surface type and condition
    let surfaceCode = values.stringAt(APTRunwayField.SURFACE_TYPE_CODE.rawValue) ?? ""
    let conditionCode = values.stringAt(APTRunwayField.COND.rawValue)
    let (materials, condition) = parseRunwaySurface(surfaceCode, conditionCode: conditionCode)

    // Parse treatment
    let treatmentCode = values.stringAt(APTRunwayField.TREATMENT_CODE.rawValue)
    let treatment: Runway.Treatment? =
      if let code = treatmentCode, code != "NONE" {
        Runway.Treatment(rawValue: code)
      } else {
        nil
      }

    // Parse pavement classification
    let pavementClassification = try parsePavementClassification(values)

    // Parse edge lights
    let edgeLightCode = values.stringAt(APTRunwayField.RWY_LGT_CODE.rawValue)
    let edgeLightsIntensity: Runway.EdgeLightIntensity? =
      if let code = edgeLightCode {
        Runway.EdgeLightIntensity.for(code)
      } else {
        nil
      }

    // Parse length source info
    let lengthSource = values.stringAt(APTRunwayField.RWY_LEN_SOURCE.rawValue)
    let lengthSourceDate = values.stringAt(APTRunwayField.LENGTH_SOURCE_DATE.rawValue).flatMap {
      CSVTransformer.yearMonthDaySlash.date(from: $0)
    }

    // Parse weight bearing capacities (values are in thousands of lbs, may be decimal like 12.5)
    let singleWheelWeight = values.doubleAt(APTRunwayField.GROSS_WT_SW.rawValue).map {
      UInt($0 * 1000)
    }
    let dualWheelWeight = values.doubleAt(APTRunwayField.GROSS_WT_DW.rawValue).map {
      UInt($0 * 1000)
    }
    let tandemDualWheelWeight =
      values.doubleAt(APTRunwayField.GROSS_WT_DTW.rawValue).map { UInt($0 * 1000) }
    let doubleTandemDualWheelWeight =
      values.doubleAt(APTRunwayField.GROSS_WT_DDTW.rawValue).map { UInt($0 * 1000) }

    // Create a placeholder RunwayEnd - will be populated later from APT_RWY_END.csv
    let placeholderEnd = RunwayEnd(
      ID: runwayId.split(separator: "/").first.map(String.init) ?? runwayId,
      trueHeading: nil,
      instrumentLandingSystem: nil,
      rightTraffic: nil,
      marking: nil,
      markingCondition: nil,
      threshold: nil,
      thresholdCrossingHeight: nil,
      visualGlidepath: nil,
      displacedThreshold: nil,
      thresholdDisplacement: nil,
      touchdownZoneElevation: nil,
      gradient: nil,
      TORA: nil,
      TODA: nil,
      ASDA: nil,
      LDA: nil,
      LAHSO: nil,
      visualGlideslopeIndicator: nil,
      RVRSensors: [],
      hasRVV: nil,
      approachLighting: nil,
      hasREIL: nil,
      hasCenterlineLighting: nil,
      endTouchdownLighting: nil,
      controllingObject: nil,
      positionSource: nil,
      positionSourceDate: nil,
      elevationSource: nil,
      elevationSourceDate: nil,
      displacedThresholdPositionSource: nil,
      displacedThresholdPositionSourceDate: nil,
      displacedThresholdElevationSource: nil,
      displacedThresholdElevationSourceDate: nil,
      touchdownZoneElevationSource: nil,
      touchdownZoneElevationSourceDate: nil
    )

    let runway = Runway(
      identification: runwayId,
      length: length,
      width: width,
      lengthSource: lengthSource,
      lengthSourceDate: lengthSourceDate,
      materials: materials,
      condition: condition,
      treatment: treatment,
      pavementClassification: pavementClassification,
      edgeLightsIntensity: edgeLightsIntensity,
      baseEnd: placeholderEnd,
      reciprocalEnd: nil,
      singleWheelWeightBearingCapacity: singleWheelWeight,
      dualWheelWeightBearingCapacity: dualWheelWeight,
      tandemDualWheelWeightBearingCapacity: tandemDualWheelWeight,
      doubleTandemDualWheelWeightBearingCapacity: doubleTandemDualWheelWeight
    )

    airports[compositeId]!.runways.append(runway)
  }

  private func parseRunwaySurface(_ surfaceCode: String, conditionCode: String?) -> (
    Set<Runway.Material>, Runway.Condition?
  ) {
    var materials = Set<Runway.Material>()

    // Parse materials from hyphen-separated surface codes
    for component in surfaceCode.split(separator: "-") {
      if let material = Runway.Material.for(String(component)) {
        materials.insert(material)
      }
    }

    // Parse condition from separate field
    let condition: Runway.Condition? =
      if let code = conditionCode {
        Runway.Condition.for(code)
      } else {
        nil
      }

    return (materials, condition)
  }

  private func parsePavementClassification(_ values: [String]) throws
    -> Runway.PavementClassification?
  {
    guard let pcnNumber = values.intAt(APTRunwayField.PCN.rawValue) else { return nil }

    guard
      let typeCode = values.stringAt(APTRunwayField.PAVEMENT_TYPE_CODE.rawValue),
      let type = Runway.PavementClassification.Classification(rawValue: typeCode)
    else { return nil }

    guard
      let strengthCode = values.stringAt(APTRunwayField.SUBGRADE_STRENGTH_CODE.rawValue),
      let strength = Runway.PavementClassification.SubgradeStrengthCategory(rawValue: strengthCode)
    else { return nil }

    guard
      let tirePressureCode = values.stringAt(APTRunwayField.TIRE_PRES_CODE.rawValue),
      let tirePressure = Runway.PavementClassification.TirePressureLimit(rawValue: tirePressureCode)
    else { return nil }

    guard
      let determinationCode = values.stringAt(APTRunwayField.DTRM_METHOD_CODE.rawValue),
      let determination = Runway.PavementClassification.DeterminationMethod(
        rawValue: determinationCode
      )
    else { return nil }

    return Runway.PavementClassification(
      number: UInt(pcnNumber),
      type: type,
      subgradeStrengthCategory: strength,
      tirePressureLimit: tirePressure,
      determinationMethod: determination
    )
  }

  // MARK: - Runway End Parsing

  private func parseRunwayEndRecord(_ values: [String]) throws {
    let siteNo = values[APTRunwayEndField.SITE_NO.rawValue]
    let siteTypeCode = values[APTRunwayEndField.SITE_TYPE_CODE.rawValue]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard airports[compositeId] != nil else { return }

    let runwayId = values[APTRunwayEndField.RWY_ID.rawValue]
    let runwayEndId = values[APTRunwayEndField.RWY_END_ID.rawValue]

    // Find the runway for this end
    guard
      let runwayIndex = airports[compositeId]!.runways.firstIndex(where: {
        $0.identification == runwayId
      })
    else { return }

    let runwayEnd = try buildRunwayEnd(from: values)

    // Determine if this is base or reciprocal end
    let runwayComponents = runwayId.split(separator: "/")

    if runwayComponents.count >= 1 && runwayEndId == String(runwayComponents[0]) {
      // This is the base end
      airports[compositeId]!.runways[runwayIndex].baseEnd = runwayEnd
    } else if runwayComponents.count >= 2 && runwayEndId == String(runwayComponents[1]) {
      // This is the reciprocal end
      airports[compositeId]!.runways[runwayIndex].reciprocalEnd = runwayEnd
    }
  }

  private func buildRunwayEnd(from values: [String]) throws -> RunwayEnd {
    let endId = values[APTRunwayEndField.RWY_END_ID.rawValue]
    let trueHeading = values.intAt(APTRunwayEndField.TRUE_ALIGNMENT.rawValue).map { UInt($0) }

    // Parse ILS type
    let ilsCode = values.stringAt(APTRunwayEndField.ILS_TYPE.rawValue)
    let instrumentLandingSystem: RunwayEnd.InstrumentLandingSystem? =
      if let code = ilsCode {
        RunwayEnd.InstrumentLandingSystem.for(code)
      } else {
        nil
      }

    // Parse right traffic
    let rightTrafficFlag = values.stringAt(APTRunwayEndField.RIGHT_HAND_TRAFFIC_PAT_FLAG.rawValue)
    let rightTraffic: Bool? =
      if let flag = rightTrafficFlag {
        flag == "Y"
      } else {
        nil
      }

    // Parse marking and condition
    let markingCode = values.stringAt(APTRunwayEndField.RWY_MARKING_TYPE_CODE.rawValue)
    let marking: RunwayEnd.Marking? =
      if let code = markingCode, code != "NONE" {
        RunwayEnd.Marking(rawValue: code)
      } else {
        nil
      }

    let markingCondCode = values.stringAt(APTRunwayEndField.RWY_MARKING_COND.rawValue)
    let markingCondition: RunwayEnd.MarkingCondition? =
      if let code = markingCondCode {
        RunwayEnd.MarkingCondition.for(code)
      } else {
        nil
      }

    // Parse threshold location
    let threshold = parseThresholdLocation(values)

    // Parse threshold crossing height
    let thresholdCrossingHeight =
      values.intAt(APTRunwayEndField.THR_CROSSING_HGT.rawValue).map { UInt($0) }

    // Parse visual glidepath angle
    let visualGlidepath =
      values.doubleAt(APTRunwayEndField.VISUAL_GLIDE_PATH_ANGLE.rawValue).map { Float($0) }

    // Parse displaced threshold
    let displacedThreshold = parseDisplacedThresholdLocation(values)

    // Parse threshold displacement distance
    let thresholdDisplacement =
      values.intAt(APTRunwayEndField.DISPLACED_THR_LEN.rawValue).map { UInt($0) }

    // Parse TDZE
    let touchdownZoneElevation =
      values.doubleAt(APTRunwayEndField.TDZ_ELEV.rawValue).map { Float($0) }

    // Parse VGSI
    let vgsiCode = values.stringAt(APTRunwayEndField.VGSI_CODE.rawValue)
    let visualGlideslopeIndicator: RunwayEnd.VisualGlideslopeIndicator? =
      if let code = vgsiCode {
        try? parseVGSI(code)
      } else {
        nil
      }

    // Parse RVR sensors
    let rvrCode = values.stringAt(APTRunwayEndField.RWY_VISUAL_RANGE_EQUIP_CODE.rawValue) ?? ""
    let RVRSensors = parseRVRSensors(rvrCode)

    // Parse RVV
    let hasRVVFlag = values.stringAt(APTRunwayEndField.RWY_VSBY_VALUE_EQUIP_FLAG.rawValue)
    let hasRVV: Bool? =
      if let flag = hasRVVFlag {
        flag == "Y"
      } else {
        nil
      }

    // Parse approach lighting
    let approachLightCode = values.stringAt(APTRunwayEndField.APCH_LGT_SYSTEM_CODE.rawValue)
    let approachLighting: RunwayEnd.ApproachLighting? =
      if let code = approachLightCode, code != "NONE" {
        RunwayEnd.ApproachLighting(rawValue: code)
      } else {
        nil
      }

    // Parse REIL
    let hasREILFlag = values.stringAt(APTRunwayEndField.RWY_END_LGTS_FLAG.rawValue)
    let hasREIL: Bool? =
      if let flag = hasREILFlag {
        flag == "Y"
      } else {
        nil
      }

    // Parse centerline lighting
    let hasCLFlag = values.stringAt(APTRunwayEndField.CNTRLN_LGTS_AVBL_FLAG.rawValue)
    let hasCenterlineLighting: Bool? =
      if let flag = hasCLFlag {
        flag == "Y"
      } else {
        nil
      }

    // Parse TDZ lighting
    let hasTDZFlag = values.stringAt(APTRunwayEndField.TDZ_LGT_AVBL_FLAG.rawValue)
    let endTouchdownLighting: Bool? =
      if let flag = hasTDZFlag {
        flag == "Y"
      } else {
        nil
      }

    // Parse controlling object
    let controllingObject = parseControllingObject(values)

    // Parse gradient
    let gradient = parseGradient(values)

    // Parse TORA/TODA/ASDA/LDA
    let TORA = values.intAt(APTRunwayEndField.TKOF_RUN_AVBL.rawValue).map { UInt($0) }
    let TODA = values.intAt(APTRunwayEndField.TKOF_DIST_AVBL.rawValue).map { UInt($0) }
    let ASDA = values.intAt(APTRunwayEndField.ACLT_STOP_DIST_AVBL.rawValue).map { UInt($0) }
    let LDA = values.intAt(APTRunwayEndField.LNDG_DIST_AVBL.rawValue).map { UInt($0) }

    // Parse LAHSO
    let LAHSO = parseLAHSO(values)

    // Parse source info
    let positionSource = values.stringAt(APTRunwayEndField.RWY_END_PSN_SOURCE.rawValue)
    let positionSourceDate =
      values.stringAt(APTRunwayEndField.RWY_END_PSN_DATE.rawValue).flatMap {
        CSVTransformer.yearMonthDaySlash.date(from: $0)
      }

    let elevationSource = values.stringAt(APTRunwayEndField.RWY_END_ELEV_SOURCE.rawValue)
    let elevationSourceDate =
      values.stringAt(APTRunwayEndField.RWY_END_ELEV_DATE.rawValue).flatMap {
        CSVTransformer.yearMonthDaySlash.date(from: $0)
      }

    let displacedThresholdPositionSource =
      values.stringAt(APTRunwayEndField.DSPL_THR_PSN_SOURCE.rawValue)
    let displacedThresholdPositionSourceDate =
      values.stringAt(APTRunwayEndField.RWY_END_DSPL_THR_PSN_DATE.rawValue).flatMap {
        CSVTransformer.yearMonthDaySlash.date(from: $0)
      }

    let displacedThresholdElevationSource =
      values.stringAt(APTRunwayEndField.DSPL_THR_ELEV_SOURCE.rawValue)
    let displacedThresholdElevationSourceDate =
      values.stringAt(APTRunwayEndField.RWY_END_DSPL_THR_ELEV_DATE.rawValue).flatMap {
        CSVTransformer.yearMonthDaySlash.date(from: $0)
      }

    let touchdownZoneElevationSource =
      values.stringAt(APTRunwayEndField.TDZ_ELEV_SOURCE.rawValue)
    let touchdownZoneElevationSourceDate =
      values.stringAt(APTRunwayEndField.RWY_END_TDZ_ELEV_DATE.rawValue).flatMap {
        CSVTransformer.yearMonthDaySlash.date(from: $0)
      }

    return RunwayEnd(
      ID: endId,
      trueHeading: trueHeading,
      instrumentLandingSystem: instrumentLandingSystem,
      rightTraffic: rightTraffic,
      marking: marking,
      markingCondition: markingCondition,
      threshold: threshold,
      thresholdCrossingHeight: thresholdCrossingHeight,
      visualGlidepath: visualGlidepath,
      displacedThreshold: displacedThreshold,
      thresholdDisplacement: thresholdDisplacement,
      touchdownZoneElevation: touchdownZoneElevation,
      gradient: gradient,
      TORA: TORA,
      TODA: TODA,
      ASDA: ASDA,
      LDA: LDA,
      LAHSO: LAHSO,
      visualGlideslopeIndicator: visualGlideslopeIndicator,
      RVRSensors: RVRSensors,
      hasRVV: hasRVV,
      approachLighting: approachLighting,
      hasREIL: hasREIL,
      hasCenterlineLighting: hasCenterlineLighting,
      endTouchdownLighting: endTouchdownLighting,
      controllingObject: controllingObject,
      positionSource: positionSource,
      positionSourceDate: positionSourceDate,
      elevationSource: elevationSource,
      elevationSourceDate: elevationSourceDate,
      displacedThresholdPositionSource: displacedThresholdPositionSource,
      displacedThresholdPositionSourceDate: displacedThresholdPositionSourceDate,
      displacedThresholdElevationSource: displacedThresholdElevationSource,
      displacedThresholdElevationSourceDate: displacedThresholdElevationSourceDate,
      touchdownZoneElevationSource: touchdownZoneElevationSource,
      touchdownZoneElevationSourceDate: touchdownZoneElevationSourceDate
    )
  }

  private func parseThresholdLocation(_ values: [String]) -> Location? {
    guard let latDecimal = values.doubleAt(APTRunwayEndField.LAT_DECIMAL.rawValue),
      let longDecimal = values.doubleAt(APTRunwayEndField.LONG_DECIMAL.rawValue)
    else { return nil }

    // Convert decimal degrees to arc-seconds for Location
    let latArcSec = Float(latDecimal * 3600)
    let longArcSec = Float(longDecimal * 3600)
    let elevation = values.doubleAt(APTRunwayEndField.RWY_END_ELEV.rawValue).map { Float($0) }

    return Location(latitude: latArcSec, longitude: longArcSec, elevation: elevation)
  }

  private func parseDisplacedThresholdLocation(_ values: [String]) -> Location? {
    guard
      let latDecimal = values.doubleAt(APTRunwayEndField.LAT_DISPLACED_THR_DECIMAL.rawValue),
      let longDecimal = values.doubleAt(APTRunwayEndField.LONG_DISPLACED_THR_DECIMAL.rawValue)
    else { return nil }

    // Convert decimal degrees to arc-seconds for Location
    let latArcSec = Float(latDecimal * 3600)
    let longArcSec = Float(longDecimal * 3600)
    let elevation = values.doubleAt(APTRunwayEndField.DISPLACED_THR_ELEV.rawValue).map { Float($0) }

    return Location(latitude: latArcSec, longitude: longArcSec, elevation: elevation)
  }

  private func parseVGSI(_ value: String) throws -> RunwayEnd.VisualGlideslopeIndicator? {
    if value.isEmpty || value == "N" || value == "NONE" { return nil }

    switch value {
      case "NSTD": return RunwayEnd.VisualGlideslopeIndicator(type: .nonstandard)
      case "PVT": return RunwayEnd.VisualGlideslopeIndicator(type: .private)
      case "VAS": return RunwayEnd.VisualGlideslopeIndicator(type: .nonspecificVASI)
      default:
        // Parse patterns like P4L, V4R, S2L, TRIL, PSIL, PNIL
        if value.hasPrefix("P") && value.count >= 3 {
          // PAPI: P<number><side>
          if let numChar = value.dropFirst().first, let number = UInt(String(numChar)) {
            let sideChar = String(value.suffix(1))
            let side = RunwayEnd.VisualGlideslopeIndicator.Side(rawValue: sideChar)
            return RunwayEnd.VisualGlideslopeIndicator(type: .PAPI, number: number, side: side)
          }
        }
        if value.hasPrefix("V") && value.count >= 2 {
          // VASI: V<number>[<side>]
          let remaining = String(value.dropFirst())
          if let numChar = remaining.first, let number = UInt(String(numChar)) {
            let sideChar = remaining.count > 1 ? String(remaining.suffix(1)) : nil
            let side = sideChar.flatMap { RunwayEnd.VisualGlideslopeIndicator.Side(rawValue: $0) }
            return RunwayEnd.VisualGlideslopeIndicator(type: .VASI, number: number, side: side)
          }
          // Large VASI: VL or VR
          if let side = RunwayEnd.VisualGlideslopeIndicator.Side(rawValue: remaining) {
            return RunwayEnd.VisualGlideslopeIndicator(type: .VASI, number: nil, side: side)
          }
        }
        if value.hasPrefix("S") && value.count >= 3 {
          // SAVASI: S<number><side>
          if let numChar = value.dropFirst().first, let number = UInt(String(numChar)) {
            let sideChar = String(value.suffix(1))
            let side = RunwayEnd.VisualGlideslopeIndicator.Side(rawValue: sideChar)
            return RunwayEnd.VisualGlideslopeIndicator(type: .SAVASI, number: number, side: side)
          }
        }
        if value.hasPrefix("TRI") {
          let sideChar = String(value.suffix(1))
          let side = RunwayEnd.VisualGlideslopeIndicator.Side(rawValue: sideChar)
          return RunwayEnd.VisualGlideslopeIndicator(type: .tricolorVASI, number: nil, side: side)
        }
        if value.hasPrefix("PSI") {
          let sideChar = String(value.suffix(1))
          let side = RunwayEnd.VisualGlideslopeIndicator.Side(rawValue: sideChar)
          return RunwayEnd.VisualGlideslopeIndicator(
            type: .pulsatingVASI,
            number: nil,
            side: side
          )
        }
        if value.hasPrefix("PNI") {
          let sideChar = String(value.suffix(1))
          let side = RunwayEnd.VisualGlideslopeIndicator.Side(rawValue: sideChar)
          return RunwayEnd.VisualGlideslopeIndicator(type: .panels, number: nil, side: side)
        }
        return nil
    }
  }

  private func parseRVRSensors(_ code: String) -> [RunwayEnd.RVRSensor] {
    var sensors = [RunwayEnd.RVRSensor]()
    for char in code {
      if let sensor = RunwayEnd.RVRSensor(rawValue: String(char)) {
        sensors.append(sensor)
      }
    }
    return sensors
  }

  private func parseControllingObject(_ values: [String]) -> RunwayEnd.ControllingObject? {
    guard let categoryCode = values.stringAt(APTRunwayEndField.OBSTN_TYPE.rawValue) else {
      return nil
    }

    let category = RunwayEnd.ControllingObject.Category(rawValue: categoryCode)

    // Parse markings
    var markings = [RunwayEnd.ControllingObject.Marking]()
    if let markingCode = values.stringAt(APTRunwayEndField.OBSTN_MRKD_CODE.rawValue) {
      for char in markingCode {
        if let marking = RunwayEnd.ControllingObject.Marking(rawValue: String(char)) {
          markings.append(marking)
        }
      }
    }

    let runwayCategory = values.stringAt(APTRunwayEndField.FAR_PART_77_CODE.rawValue)
    let clearanceSlope = values.intAt(APTRunwayEndField.OBSTN_CLNC_SLOPE.rawValue).map { UInt($0) }
    let heightAboveRunway = values.intAt(APTRunwayEndField.OBSTN_HGT.rawValue).map { UInt($0) }
    let distanceFromRunway = values.intAt(APTRunwayEndField.DIST_FROM_THR.rawValue).map { UInt($0) }

    // Parse offset
    let offsetFromCenterline = parseOffset(values)

    return RunwayEnd.ControllingObject(
      category: category,
      markings: markings,
      runwayCategory: runwayCategory,
      clearanceSlope: clearanceSlope,
      heightAboveRunway: heightAboveRunway,
      distanceFromRunway: distanceFromRunway,
      offsetFromCenterline: offsetFromCenterline
    )
  }

  private func parseOffset(_ values: [String]) -> Offset? {
    guard let distance = values.intAt(APTRunwayEndField.CNTRLN_OFFSET.rawValue) else { return nil }
    let directionCode = values.stringAt(APTRunwayEndField.CNTRLN_DIR_CODE.rawValue)

    let direction: Offset.Direction =
      if let code = directionCode, let dir = Offset.Direction.from(string: code) {
        dir
      } else {
        .left  // Default fallback
      }

    return Offset(distance: UInt(distance), direction: direction)
  }

  private func parseGradient(_ values: [String]) -> Float? {
    guard let gradientValue = values.doubleAt(APTRunwayEndField.RWY_GRAD.rawValue) else {
      return nil
    }

    var gradient = Float(gradientValue)
    let directionCode = values.stringAt(APTRunwayEndField.RWY_GRAD_DIRECTION.rawValue)
    if directionCode == "DOWN" {
      gradient *= -1
    }

    return gradient
  }

  private func parseLAHSO(_ values: [String]) -> RunwayEnd.LAHSOPoint? {
    guard let availableDistance = values.intAt(APTRunwayEndField.LAHSO_ALD.rawValue) else {
      return nil
    }

    let intersectingRunwayID =
      values.stringAt(APTRunwayEndField.RWY_END_INTERSECT_LAHSO.rawValue)
    let definingEntity = values.stringAt(APTRunwayEndField.LAHSO_DESC.rawValue)

    // Parse LAHSO position
    var position: Location?
    if let latDecimal = values.doubleAt(APTRunwayEndField.LAT_LAHSO_DECIMAL.rawValue),
      let longDecimal = values.doubleAt(APTRunwayEndField.LONG_LAHSO_DECIMAL.rawValue)
    {
      let latArcSec = Float(latDecimal * 3600)
      let longArcSec = Float(longDecimal * 3600)
      position = Location(latitude: latArcSec, longitude: longArcSec, elevation: nil)
    }

    let positionSource = values.stringAt(APTRunwayEndField.LAHSO_PSN_SOURCE.rawValue)
    let positionSourceDate =
      values.stringAt(APTRunwayEndField.RWY_END_LAHSO_PSN_DATE.rawValue).flatMap {
        CSVTransformer.yearMonthDaySlash.date(from: $0)
      }

    return RunwayEnd.LAHSOPoint(
      availableDistance: UInt(availableDistance),
      intersectingRunwayID: intersectingRunwayID,
      definingEntity: definingEntity,
      position: position,
      positionSource: positionSource,
      positionSourceDate: positionSourceDate
    )
  }

  // MARK: - Attendance Schedule Parsing

  private func parseAttendanceRecord(_ values: [String]) throws {
    let siteNo = values[APTAttendanceField.SITE_NO.rawValue]
    let siteTypeCode = values[APTAttendanceField.SITE_TYPE_CODE.rawValue]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard airports[compositeId] != nil else { return }

    let month = values.stringAt(APTAttendanceField.MONTH.rawValue) ?? ""
    let day = values.stringAt(APTAttendanceField.DAY.rawValue) ?? ""
    let hour = values.stringAt(APTAttendanceField.HOUR.rawValue) ?? ""

    // Skip unattended entries
    if month == "UNATNDD" || month == "UNATTND" { return }

    let schedule: AttendanceSchedule
    if !month.isEmpty && !day.isEmpty && !hour.isEmpty {
      schedule = .components(monthly: month, daily: day, hourly: hour)
    } else {
      // Concatenate non-empty parts as custom schedule
      let parts = [month, day, hour].filter { !$0.isEmpty }
      if parts.isEmpty { return }
      schedule = .custom(parts.joined(separator: "/"))
    }

    airports[compositeId]!.attendanceSchedule.append(schedule)
  }

  // MARK: - Remarks Parsing

  private func parseRemarkRecord(_ values: [String]) throws {
    let siteNo = values[APTRemarkField.SITE_NO.rawValue]
    let siteTypeCode = values[APTRemarkField.SITE_TYPE_CODE.rawValue]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard airports[compositeId] != nil else { return }

    let tabName = values.stringAt(APTRemarkField.TAB_NAME.rawValue) ?? ""
    let element = values.stringAt(APTRemarkField.ELEMENT.rawValue) ?? ""
    let remark = values.stringAt(APTRemarkField.REMARK.rawValue) ?? ""

    if remark.isEmpty { return }

    switch tabName {
      case "AIRPORT":
        // Airport-level remarks
        airports[compositeId]!.remarks.append(.general(remark))

      case "RUNWAY":
        // Runway-specific remarks
        if let runwayIndex = airports[compositeId]!.runways.firstIndex(where: {
          $0.identification == element
        }) {
          airports[compositeId]!.runways[runwayIndex].remarks.append(.general(remark))
        }

      case "RUNWAY_END":
        // Runway end-specific remarks
        updateRunwayEnd(element, inAirport: &airports[compositeId]!) { end in
          end.remarks.append(.general(remark))
        }

      case "AIRPORT_CONTACT":
        // Owner/manager remarks
        if element == "OWNER" {
          airports[compositeId]!.owner?.remarks.append(.general(remark))
        } else if element == "MANAGER" {
          airports[compositeId]!.manager?.remarks.append(.general(remark))
        }

      case "FUEL_TYPE":
        // Fuel-specific remarks
        if let fuelType = Airport.FuelType(rawValue: element) {
          airports[compositeId]!.remarks.append(
            .fuel(field: .fuelsAvailable, fuel: fuelType, content: remark)
          )
        }

      default:
        // Unknown tab, add as general remark
        airports[compositeId]!.remarks.append(.general(remark))
    }
  }

  @discardableResult
  private func updateRunwayEnd(
    _ identifier: String,
    inAirport airport: inout Airport,
    process: (inout RunwayEnd) -> Void
  ) -> Bool {
    for (index, runway) in airport.runways.enumerated() {
      if runway.baseEnd.ID == identifier {
        var end = runway.baseEnd
        process(&end)
        airport.runways[index].baseEnd = end
        return true
      }
      if let reciprocal = runway.reciprocalEnd, reciprocal.ID == identifier {
        var end = reciprocal
        process(&end)
        airport.runways[index].reciprocalEnd = end
        return true
      }
    }
    return false
  }

  // MARK: - Arresting Systems Parsing

  private func parseArrestingSystemRecord(_ values: [String]) throws {
    let siteNo = values[APTArrestingSystemField.SITE_NO.rawValue]
    let siteTypeCode = values[APTArrestingSystemField.SITE_TYPE_CODE.rawValue]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard airports[compositeId] != nil else { return }

    let runwayId = values[APTArrestingSystemField.RWY_ID.rawValue]
    let runwayEndId = values[APTArrestingSystemField.RWY_END_ID.rawValue]
    let deviceCode = values.stringAt(APTArrestingSystemField.ARREST_DEVICE_CODE.rawValue) ?? ""

    if deviceCode.isEmpty { return }

    // Find the runway
    guard
      let runwayIndex = airports[compositeId]!.runways.firstIndex(where: {
        $0.identification == runwayId
      })
    else { return }

    let runway = airports[compositeId]!.runways[runwayIndex]

    // Determine which end this arresting system belongs to
    if runway.baseEnd.ID == runwayEndId {
      airports[compositeId]!.runways[runwayIndex].baseEnd.arrestingSystems.append(deviceCode)
    } else if runway.reciprocalEnd?.ID == runwayEndId {
      airports[compositeId]!.runways[runwayIndex].reciprocalEnd!.arrestingSystems.append(deviceCode)
    }
  }

  // MARK: - Contacts Parsing

  private func parseContactRecord(_ values: [String]) throws {
    let siteNo = values[APTContactField.SITE_NO.rawValue]
    let siteTypeCode = values[APTContactField.SITE_TYPE_CODE.rawValue]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard airports[compositeId] != nil else { return }

    let title = values.stringAt(APTContactField.TITLE.rawValue) ?? ""
    let name = values.stringAt(APTContactField.NAME.rawValue) ?? ""
    let address1 = values.stringAt(APTContactField.ADDRESS1.rawValue)
    let address2 = values.stringAt(APTContactField.ADDRESS2.rawValue)
    let city = values.stringAt(APTContactField.TITLE_CITY.rawValue) ?? ""
    let state = values.stringAt(APTContactField.STATE.rawValue) ?? ""
    let zipCode = values.stringAt(APTContactField.ZIP_CODE.rawValue) ?? ""
    let zipPlusFour = values.stringAt(APTContactField.ZIP_PLUS_FOUR.rawValue)
    let phone = values.stringAt(APTContactField.PHONE_NO.rawValue)

    if name.isEmpty { return }

    // Build full address2 with city, state, zip
    var fullAddress2: String? = address2
    if !city.isEmpty || !state.isEmpty || !zipCode.isEmpty {
      var cityStateZip = city
      if !state.isEmpty {
        if !cityStateZip.isEmpty { cityStateZip += ", " }
        cityStateZip += state
      }
      if !zipCode.isEmpty {
        if !cityStateZip.isEmpty { cityStateZip += " " }
        cityStateZip += zipCode
        if let plus4 = zipPlusFour, !plus4.isEmpty {
          cityStateZip += "-\(plus4)"
        }
      }
      if let existing = fullAddress2, !existing.isEmpty {
        fullAddress2 = "\(existing), \(cityStateZip)"
      } else {
        fullAddress2 = cityStateZip
      }
    }

    let person = Airport.Person(
      name: name,
      address1: address1,
      address2: fullAddress2,
      phone: phone
    )

    if title == "OWNER" {
      airports[compositeId]!.owner = person
    } else if title == "MANAGER" {
      airports[compositeId]!.manager = person
    }
  }
}
