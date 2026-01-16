import Foundation
import StreamingCSV

/// CSV Airport Parser using header-based field access
actor CSVAirportParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = [
    "FRQ.csv", "APT_BASE.csv", "APT_CON.csv", "APT_RWY.csv",
    "APT_RWY_END.csv", "APT_ARS.csv", "APT_ATT.csv", "APT_RMK.csv"
  ]

  var airports = [String: Airport]()

  /// Temporary storage for UNICOM frequencies from FRQ.csv
  /// Key is the SERVICED_FACILITY (airport ID)
  private var unicomFrequencies = [String: UInt]()

  /// Temporary storage for CTAF frequencies from FRQ.csv
  /// Key is the SERVICED_FACILITY (airport ID)
  private var ctafFrequencies = [String: UInt]()

  // MARK: - Transformers

  private let baseTransformer = CSVTransformer([
    .init("SITE_NO", .string()),
    .init("SITE_TYPE_CODE", .string()),
    .init("ARPT_ID", .string()),
    .init("ARPT_NAME", .string()),
    .init("LAT_DECIMAL", .float(nullable: .blank)),
    .init("LONG_DECIMAL", .float(nullable: .blank)),
    .init("ELEV", .float(nullable: .blank)),
    .init("REGION_CODE", .recordEnum(Airport.FAARegion.self, nullable: .blank)),
    .init("OWNERSHIP_TYPE_CODE", .recordEnum(Airport.Ownership.self)),
    .init("FACILITY_USE_CODE", .string(nullable: .blank)),
    .init("SURVEY_METHOD_CODE", .recordEnum(SurveyMethod.self)),
    .init("ELEV_METHOD_CODE", .recordEnum(SurveyMethod.self, nullable: .blank)),
    .init("MAG_VARN", .integer(nullable: .blank)),
    .init("MAG_HEMIS", .string(nullable: .blank)),
    .init("MAG_VARN_YEAR", .dateComponents(format: .yearOnly, nullable: .blank)),
    .init("TPA", .integer(nullable: .blank)),
    .init("CHART_NAME", .string(nullable: .blank)),
    .init("DIST_CITY_TO_AIRPORT", .unsignedInteger(nullable: .blank)),
    .init("DIRECTION_CODE", .recordEnum(Direction.self, nullable: .blank)),
    .init("ACREAGE", .float(nullable: .blank)),
    .init("COMPUTER_ID", .string(nullable: .blank)),
    .init("RESP_ARTCC_ID", .string()),
    .init("FSS_ON_ARPT_FLAG", .boolean(nullable: .blank)),
    .init("FSS_ID", .string()),
    .init("ALT_FSS_ID", .string(nullable: .blank)),
    .init("NOTAM_ID", .string(nullable: .blank)),
    .init("NOTAM_FLAG", .boolean(nullable: .blank)),
    .init("ACTIVATION_DATE", .dateComponents(format: .yearMonthSlash, nullable: .blank)),
    .init("ARPT_STATUS", .string()),
    .init("ARFF_CERT_TYPE_DATE", .string(nullable: .blank)),
    .init("NASP_CODE", .string(nullable: .blank)),
    .init(
      "ASP_ANLYS_DTRM_CODE",
      .recordEnum(Airport.AirspaceAnalysisDetermination.self, nullable: .blank)
    ),
    .init("CUST_FLAG", .boolean(nullable: .blank)),
    .init("LNDG_RIGHTS_FLAG", .boolean(nullable: .blank)),
    .init("JOINT_USE_FLAG", .boolean(nullable: .blank)),
    .init("MIL_LNDG_FLAG", .boolean(nullable: .blank)),
    .init("INSPECT_METHOD_CODE", .recordEnum(Airport.InspectionMethod.self, nullable: .blank)),
    .init("INSPECTOR_CODE", .recordEnum(Airport.InspectionAgency.self, nullable: .blank)),
    .init("LAST_INSPECTION", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("LAST_INFO_RESPONSE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("FUEL_TYPES", .string(nullable: .blank)),
    .init("AIRFRAME_REPAIR_SER_CODE", .recordEnum(Airport.RepairService.self, nullable: .blank)),
    .init("PWR_PLANT_REPAIR_SER", .recordEnum(Airport.RepairService.self, nullable: .blank)),
    .init("BOTTLED_OXY_TYPE", .string(nullable: .blank)),
    .init("BULK_OXY_TYPE", .string(nullable: .blank)),
    .init("LGT_SKED", .string(nullable: .blank)),
    .init("BCN_LGT_SKED", .string(nullable: .blank)),
    .init("TWR_TYPE_CODE", .string(nullable: .blank)),
    .init("SEG_CIRCLE_MKR_FLAG", .recordEnum(Airport.AirportMarker.self, nullable: .blank)),
    .init("BCN_LENS_COLOR", .recordEnum(Airport.LensColor.self, nullable: .blank)),
    .init("LNDG_FEE_FLAG", .boolean(nullable: .blank)),
    .init("MEDICAL_USE_FLAG", .boolean(nullable: .blank)),
    .init("OTHER_SERVICES", .string(nullable: .blank)),
    .init("WIND_INDCR_FLAG", .recordEnum(Airport.AirportMarker.self, nullable: .blank)),
    .init("ICAO_ID", .string(nullable: .blank)),
    .init("ADO_CODE", .string(nullable: .blank)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("COUNTY_NAME", .string()),
    .init("COUNTY_ASSOC_STATE", .string()),
    .init("CITY", .string()),
    .init("TRNS_STRG_BUOY_FLAG", .boolean(nullable: .blank)),
    .init("TRNS_STRG_HGR_FLAG", .boolean(nullable: .blank)),
    .init("TRNS_STRG_TIE_FLAG", .boolean(nullable: .blank)),
    .init("ARPT_PSN_SOURCE", .string(nullable: .blank)),
    .init("POSITION_SRC_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("ARPT_ELEV_SOURCE", .string(nullable: .blank)),
    .init("ELEVATION_SRC_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("CONTR_FUEL_AVBL", .boolean(nullable: .blank)),
    .init("MIN_OP_NETWORK", .boolean(nullable: .blank))
  ])

  private let runwayTransformer = CSVTransformer([
    .init("SITE_NO", .string()),
    .init("SITE_TYPE_CODE", .string()),
    .init("RWY_ID", .string()),
    .init("RWY_LEN", .unsignedInteger(nullable: .blank)),
    .init("RWY_WIDTH", .unsignedInteger(nullable: .blank)),
    .init("SURFACE_TYPE_CODE", .string(nullable: .blank)),
    .init("COND", .string(nullable: .blank)),
    .init("TREATMENT_CODE", .string(nullable: .blank)),
    .init("RWY_LGT_CODE", .string(nullable: .blank)),
    .init("RWY_LEN_SOURCE", .string(nullable: .blank)),
    .init("LENGTH_SOURCE_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("GROSS_WT_SW", .float(nullable: .blank)),
    .init("GROSS_WT_DW", .float(nullable: .blank)),
    .init("GROSS_WT_DTW", .float(nullable: .blank)),
    .init("GROSS_WT_DDTW", .float(nullable: .blank)),
    .init("PCN", .integer(nullable: .blank)),
    .init("PAVEMENT_TYPE_CODE", .string(nullable: .blank)),
    .init("SUBGRADE_STRENGTH_CODE", .string(nullable: .blank)),
    .init("TIRE_PRES_CODE", .string(nullable: .blank)),
    .init("DTRM_METHOD_CODE", .string(nullable: .blank))
  ])

  private let runwayEndTransformer = CSVTransformer([
    .init("SITE_NO", .string()),
    .init("SITE_TYPE_CODE", .string()),
    .init("RWY_ID", .string()),
    .init("RWY_END_ID", .string()),
    .init("TRUE_ALIGNMENT", .integer(nullable: .blank)),
    .init("ILS_TYPE", .string(nullable: .blank)),
    .init("RIGHT_HAND_TRAFFIC_PAT_FLAG", .string(nullable: .blank)),
    .init("RWY_MARKING_TYPE_CODE", .string(nullable: .blank)),
    .init("RWY_MARKING_COND", .string(nullable: .blank)),
    .init("LAT_DECIMAL", .float(nullable: .blank)),
    .init("LONG_DECIMAL", .float(nullable: .blank)),
    .init("RWY_END_ELEV", .float(nullable: .blank)),
    .init("THR_CROSSING_HGT", .unsignedInteger(nullable: .blank)),
    .init("VISUAL_GLIDE_PATH_ANGLE", .float(nullable: .blank)),
    .init("LAT_DISPLACED_THR_DECIMAL", .float(nullable: .blank)),
    .init("LONG_DISPLACED_THR_DECIMAL", .float(nullable: .blank)),
    .init("DISPLACED_THR_ELEV", .float(nullable: .blank)),
    .init("DISPLACED_THR_LEN", .unsignedInteger(nullable: .blank)),
    .init("TDZ_ELEV", .float(nullable: .blank)),
    .init("VGSI_CODE", .string(nullable: .blank)),
    .init("RWY_VISUAL_RANGE_EQUIP_CODE", .string(nullable: .blank)),
    .init("RWY_VSBY_VALUE_EQUIP_FLAG", .string(nullable: .blank)),
    .init("APCH_LGT_SYSTEM_CODE", .string(nullable: .blank)),
    .init("RWY_END_LGTS_FLAG", .string(nullable: .blank)),
    .init("CNTRLN_LGTS_AVBL_FLAG", .string(nullable: .blank)),
    .init("TDZ_LGT_AVBL_FLAG", .string(nullable: .blank)),
    .init("RWY_GRAD", .float(nullable: .blank)),
    .init("RWY_GRAD_DIRECTION", .string(nullable: .blank)),
    .init("TKOF_RUN_AVBL", .unsignedInteger(nullable: .blank)),
    .init("TKOF_DIST_AVBL", .unsignedInteger(nullable: .blank)),
    .init("ACLT_STOP_DIST_AVBL", .unsignedInteger(nullable: .blank)),
    .init("LNDG_DIST_AVBL", .unsignedInteger(nullable: .blank)),
    .init("LAHSO_ALD", .unsignedInteger(nullable: .blank)),
    .init("RWY_END_INTERSECT_LAHSO", .string(nullable: .blank)),
    .init("LAHSO_DESC", .string(nullable: .blank)),
    .init("LAT_LAHSO_DECIMAL", .float(nullable: .blank)),
    .init("LONG_LAHSO_DECIMAL", .float(nullable: .blank)),
    .init("LAHSO_PSN_SOURCE", .string(nullable: .blank)),
    .init("RWY_END_LAHSO_PSN_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("RWY_END_PSN_SOURCE", .string(nullable: .blank)),
    .init("RWY_END_PSN_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("RWY_END_ELEV_SOURCE", .string(nullable: .blank)),
    .init("RWY_END_ELEV_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("DSPL_THR_PSN_SOURCE", .string(nullable: .blank)),
    .init(
      "RWY_END_DSPL_THR_PSN_DATE",
      .dateComponents(format: .yearMonthDaySlash, nullable: .blank)
    ),
    .init("DSPL_THR_ELEV_SOURCE", .string(nullable: .blank)),
    .init(
      "RWY_END_DSPL_THR_ELEV_DATE",
      .dateComponents(format: .yearMonthDaySlash, nullable: .blank)
    ),
    .init("TDZ_ELEV_SOURCE", .string(nullable: .blank)),
    .init("RWY_END_TDZ_ELEV_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("OBSTN_TYPE", .string(nullable: .blank)),
    .init("OBSTN_MRKD_CODE", .string(nullable: .blank)),
    .init("FAR_PART_77_CODE", .string(nullable: .blank)),
    .init("OBSTN_CLNC_SLOPE", .unsignedInteger(nullable: .blank)),
    .init("OBSTN_HGT", .unsignedInteger(nullable: .blank)),
    .init("DIST_FROM_THR", .unsignedInteger(nullable: .blank)),
    .init("CNTRLN_OFFSET", .unsignedInteger(nullable: .blank)),
    .init("CNTRLN_DIR_CODE", .string(nullable: .blank))
  ])

  private let frequencyTransformer = CSVTransformer([
    .init("SERVICED_FACILITY", .string(nullable: .blank)),
    .init("FREQ", .string(nullable: .blank)),
    .init("FREQ_USE", .string(nullable: .blank))
  ])

  // MARK: - Protocol Methods

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // 0. Parse frequencies first (need UNICOM/CTAF before creating airports)
    try await parseCSVFile(
      filename: "FRQ.csv",
      requiredColumns: ["SERVICED_FACILITY", "FREQ", "FREQ_USE"]
    ) { row in
      self.parseFrequencyRecord(row)
    }

    // 1. Parse base airport records
    try await parseCSVFile(
      filename: "APT_BASE.csv",
      requiredColumns: ["SITE_NO", "SITE_TYPE_CODE", "ARPT_ID", "ARPT_NAME"]
    ) { row in
      try self.parseAirportRecord(row)
    }

    // 2. Parse contacts (owner/manager info - must come before remarks)
    try await parseCSVFile(
      filename: "APT_CON.csv",
      requiredColumns: ["SITE_NO", "SITE_TYPE_CODE", "TITLE", "NAME"]
    ) { row in
      try self.parseContactRecord(row)
    }

    // 3. Parse runways
    try await parseCSVFile(
      filename: "APT_RWY.csv",
      requiredColumns: ["SITE_NO", "SITE_TYPE_CODE", "RWY_ID"]
    ) { row in
      try self.parseRunwayRecord(row)
    }

    // 4. Parse runway ends
    try await parseCSVFile(
      filename: "APT_RWY_END.csv",
      requiredColumns: ["SITE_NO", "SITE_TYPE_CODE", "RWY_ID", "RWY_END_ID"]
    ) { row in
      try self.parseRunwayEndRecord(row)
    }

    // 5. Parse arresting systems (requires runway ends to exist)
    try await parseCSVFile(
      filename: "APT_ARS.csv",
      requiredColumns: ["SITE_NO", "SITE_TYPE_CODE", "RWY_ID", "RWY_END_ID"]
    ) { row in
      try self.parseArrestingSystemRecord(row)
    }

    // 6. Parse attendance schedules
    try await parseCSVFile(
      filename: "APT_ATT.csv",
      requiredColumns: ["SITE_NO", "SITE_TYPE_CODE"]
    ) { row in
      try self.parseAttendanceRecord(row)
    }

    // 7. Parse remarks last (references runways/ends that must exist)
    try await parseCSVFile(
      filename: "APT_RMK.csv",
      requiredColumns: ["SITE_NO", "SITE_TYPE_CODE", "REMARK"]
    ) { row in
      try self.parseRemarkRecord(row)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(airports: Array(airports.values))
  }

  // MARK: - Parsing Methods

  private func parseAirportRecord(_ row: CSVRow) throws {
    let t = try baseTransformer.applyTo(row)

    // Skip non-airport site types if needed
    let validSiteTypes = ["A", "H", "C", "B", "G", "U"]
    let siteType: String = try t["SITE_TYPE_CODE"]
    guard validSiteTypes.contains(siteType) else {
      return  // Skip non-airport record types (intentional filter)
    }

    let siteNumber: String = try t["SITE_NO"]

    // Handle location
    let latDecimal: Float? = try t[optional: "LAT_DECIMAL"]
    let lonDecimal: Float? = try t[optional: "LONG_DECIMAL"]
    let elevation: Float? = try t[optional: "ELEV"]

    guard
      let location = try makeLocation(
        latitude: latDecimal,
        longitude: lonDecimal,
        elevation: elevation,
        context: "airport \(siteNumber)"
      )
    else {
      throw ParserError.missingRequiredField(field: "position", recordType: "APT_BASE")
    }

    // Parse facility type
    let facilityType = try ParserHelpers.parseAirportFacilityType(siteType)

    // Parse region code
    let faaRegion: Airport.FAARegion? = try t[optional: "REGION_CODE"]

    // Parse ownership type
    let ownership: Airport.Ownership = try t["OWNERSHIP_TYPE_CODE"]

    // Parse facility use with strict validation
    let facilityUseCode: String? = try t[optional: "FACILITY_USE_CODE"]
    let publicUse: Bool
    switch facilityUseCode {
      case "PU": publicUse = true
      case "PR", nil, "": publicUse = false
      default:
        throw CSVParserError.invalidValueInColumn(facilityUseCode!, column: "FACILITY_USE_CODE")
    }

    // Parse survey method
    let surveyMethod: SurveyMethod = try t["SURVEY_METHOD_CODE"]

    // Parse elevation determination method
    let elevationMethod: SurveyMethod? = try t[optional: "ELEV_METHOD_CODE"]

    // Parse magnetic variation
    let magneticVariation: Int? = {
      guard let magVar: Int = try? t[optional: "MAG_VARN"] else { return nil }
      let hemisphere: String = (try? t[optional: "MAG_HEMIS"]) ?? ""
      return hemisphere == "W" ? -magVar : magVar
    }()

    // Parse direction city to airport
    let direction: Direction? = try t[optional: "DIRECTION_CODE"]

    // Parse ARFF capability
    let ARFFString: String? = try t[optional: "ARFF_CERT_TYPE_DATE"]
    let ARFFCapability = try parseARFFCapability(ARFFString)

    // Parse federal agreements
    let agreementCodes: String = (try? t[optional: "NASP_CODE"]) ?? ""
    let agreements: [Airport.FederalAgreement] = agreementCodes.compactMap {
      Airport.FederalAgreement(rawValue: String($0))
    }

    // Parse airspace analysis determination
    let airspaceDetermination: Airport.AirspaceAnalysisDetermination? = try t[
      optional: "ASP_ANLYS_DTRM_CODE"
    ]

    // Parse inspection method and agency
    let inspectionMethod: Airport.InspectionMethod? = try t[optional: "INSPECT_METHOD_CODE"]
    let inspectionAgency: Airport.InspectionAgency? = try t[optional: "INSPECTOR_CODE"]

    // Parse fuel types
    let fuelTypesStr: String = (try? t[optional: "FUEL_TYPES"]) ?? ""
    var fuelsAvailable = [Airport.FuelType]()
    var index = fuelTypesStr.startIndex
    while index < fuelTypesStr.endIndex {
      let endIndex =
        fuelTypesStr.index(index, offsetBy: 5, limitedBy: fuelTypesStr.endIndex)
        ?? fuelTypesStr
        .endIndex
      let fuelCode = String(fuelTypesStr[index..<endIndex]).trimmingCharacters(in: .whitespaces)
      if let fuelType = Airport.FuelType(rawValue: fuelCode) {
        fuelsAvailable.append(fuelType)
      }
      index = endIndex
    }

    // Parse repair services
    let airframeRepair: Airport.RepairService? = try t[optional: "AIRFRAME_REPAIR_SER_CODE"]
    let powerplantRepair: Airport.RepairService? = try t[optional: "PWR_PLANT_REPAIR_SER"]

    // Parse oxygen availability
    let bottledOxyStr: String = (try? t[optional: "BOTTLED_OXY_TYPE"]) ?? ""
    let bottledOxygen: [Airport.OxygenPressure] = bottledOxyStr.split(separator: "/").compactMap {
      let code = String($0).trimmingCharacters(in: .whitespaces)
      return code == "NONE" ? nil : Airport.OxygenPressure.for(code)
    }

    let bulkOxyStr: String = (try? t[optional: "BULK_OXY_TYPE"]) ?? ""
    let bulkOxygen: [Airport.OxygenPressure] = bulkOxyStr.split(separator: "/").compactMap {
      let code = String($0).trimmingCharacters(in: .whitespaces)
      return code == "NONE" ? nil : Airport.OxygenPressure.for(code)
    }

    // Parse segmented circle and beacon color
    let segmentedCircle: Airport.AirportMarker? = try t[optional: "SEG_CIRCLE_MKR_FLAG"]
    let beaconColor: Airport.LensColor? = try t[optional: "BCN_LENS_COLOR"]

    // Parse other services
    let servicesStr: String = (try? t[optional: "OTHER_SERVICES"]) ?? ""
    let otherServices: [Airport.Service] = servicesStr.split(separator: ",").compactMap {
      let code = String($0).trimmingCharacters(in: .whitespaces)
      return Airport.Service.for(code)
    }

    // Parse wind indicator
    let windIndicator: Airport.AirportMarker? = try t[optional: "WIND_INDCR_FLAG"]

    // Handle control tower based on TWR_TYPE_CODE
    let towerCode: String = (try? t[optional: "TWR_TYPE_CODE"]) ?? ""
    let controlTower = !towerCode.isEmpty && !towerCode.hasPrefix("NON")

    // Parse transient storage facilities
    var transientStorageFacilities: [Airport.StorageFacility] = []
    if (try? t[optional: "TRNS_STRG_BUOY_FLAG"]) == true {
      transientStorageFacilities.append(.buoys)
    }
    if (try? t[optional: "TRNS_STRG_HGR_FLAG"]) == true {
      transientStorageFacilities.append(.hangars)
    }
    if (try? t[optional: "TRNS_STRG_TIE_FLAG"]) == true {
      transientStorageFacilities.append(.tiedowns)
    }

    // Parse status
    let statusCode: String = try t["ARPT_STATUS"]
    let status = Airport.Status(rawValue: statusCode)!

    let airportId: String = try t["ARPT_ID"]

    let airport = Airport(
      id: siteNumber,
      name: try t["ARPT_NAME"],
      LID: airportId,
      ICAOIdentifier: try t[optional: "ICAO_ID"],
      facilityType: facilityType,
      faaRegion: faaRegion,
      FAAFieldOfficeCode: try t[optional: "ADO_CODE"],
      stateCode: try t[optional: "STATE_CODE"],
      county: try t["COUNTY_NAME"],
      countyStateCode: try t["COUNTY_ASSOC_STATE"],
      city: try t["CITY"],
      ownership: ownership,
      publicUse: publicUse,
      owner: nil,  // Parsed from APT_CON.csv after base record creation
      manager: nil,  // Parsed from APT_CON.csv after base record creation
      referencePoint: location,
      referencePointDeterminationMethod: surveyMethod,
      elevationDeterminationMethod: elevationMethod,
      magneticVariationDeg: magneticVariation,
      magneticVariationEpochComponents: try t[optional: "MAG_VARN_YEAR"],
      trafficPatternAltitudeFtAGL: try t[optional: "TPA"],
      sectionalChart: try t[optional: "CHART_NAME"],
      distanceCityToAirportNM: try t[optional: "DIST_CITY_TO_AIRPORT"],
      directionCityToAirport: direction,
      landAreaAcres: try t[optional: "ACREAGE"],
      boundaryARTCCId: try t[optional: "COMPUTER_ID"],
      responsibleARTCCId: try t["RESP_ARTCC_ID"],
      tieInFSSOnStation: try t[optional: "FSS_ON_ARPT_FLAG"],
      tieInFSSId: try t["FSS_ID"],
      alternateFSSId: try t[optional: "ALT_FSS_ID"],
      NOTAMIssuerId: try t[optional: "NOTAM_ID"],
      NOTAMDAvailable: try t[optional: "NOTAM_FLAG"],
      activationDateComponents: try t[optional: "ACTIVATION_DATE"],
      status: status,
      arffCapability: ARFFCapability,
      agreements: agreements,
      airspaceAnalysisDetermination: airspaceDetermination,
      customsEntryAirport: try t[optional: "CUST_FLAG"],
      customsLandingRightsAirport: try t[optional: "LNDG_RIGHTS_FLAG"],
      jointUseAgreement: try t[optional: "JOINT_USE_FLAG"],
      militaryLandingRights: try t[optional: "MIL_LNDG_FLAG"],
      inspectionMethod: inspectionMethod,
      inspectionAgency: inspectionAgency,
      lastPhysicalInspectionDateComponents: try t[optional: "LAST_INSPECTION"],
      lastInformationRequestCompletedDateComponents: try t[optional: "LAST_INFO_RESPONSE"],
      fuelsAvailable: fuelsAvailable,
      airframeRepairAvailable: airframeRepair,
      powerplantRepairAvailable: powerplantRepair,
      bottledOxygenAvailable: bottledOxygen,
      bulkOxygenAvailable: bulkOxygen,
      airportLightingSchedule: try t[optional: "LGT_SKED"],
      beaconLightingSchedule: try t[optional: "BCN_LGT_SKED"],
      controlTower: controlTower,
      UNICOMFrequencyKHz: unicomFrequencies[airportId],
      CTAFKHz: ctafFrequencies[airportId],
      segmentedCircle: segmentedCircle,
      beaconColor: beaconColor,
      hasLandingFee: try t[optional: "LNDG_FEE_FLAG"],
      medicalUse: try t[optional: "MEDICAL_USE_FLAG"],
      basedSingleEngineGA: nil,  // Not in CSV distribution (TXT-only)
      basedMultiEngineGA: nil,  // Not in CSV distribution (TXT-only)
      basedJetGA: nil,  // Not in CSV distribution (TXT-only)
      basedHelicopterGA: nil,  // Not in CSV distribution (TXT-only)
      basedOperationalGliders: nil,  // Not in CSV distribution (TXT-only)
      basedOperationalMilitary: nil,  // Not in CSV distribution (TXT-only)
      basedUltralights: nil,  // Not in CSV distribution (TXT-only)
      annualCommercialOps: nil,  // Not in CSV distribution (TXT-only)
      annualCommuterOps: nil,  // Not in CSV distribution (TXT-only)
      annualAirTaxiOps: nil,  // Not in CSV distribution (TXT-only)
      annualLocalGAOps: nil,  // Not in CSV distribution (TXT-only)
      annualTransientGAOps: nil,  // Not in CSV distribution (TXT-only)
      annualMilitaryOps: nil,  // Not in CSV distribution (TXT-only)
      annualPeriodEndDateComponents: nil,  // Not in CSV distribution (TXT-only)
      positionSource: try t[optional: "ARPT_PSN_SOURCE"],
      positionSourceDateComponents: try t[optional: "POSITION_SRC_DATE"],
      elevationSource: try t[optional: "ARPT_ELEV_SOURCE"],
      elevationSourceDateComponents: try t[optional: "ELEVATION_SRC_DATE"],
      contractFuelAvailable: try t[optional: "CONTR_FUEL_AVBL"],
      transientStorageFacilities: transientStorageFacilities.presence,
      otherServices: otherServices,
      windIndicator: windIndicator,
      minimumOperationalNetwork: (try? t[optional: "MIN_OP_NETWORK"]) ?? false
    )

    // Use composite key of SITE_NO + SITE_TYPE_CODE to match TXT format
    let compositeId = "\(airport.id)*\(siteType)"
    airports[compositeId] = airport
  }

  /// Parse FRQ.csv to extract UNICOM and CTAF frequencies
  private func parseFrequencyRecord(_ row: CSVRow) {
    guard let t = try? frequencyTransformer.applyTo(row) else { return }

    guard let airportId: String = try? t[optional: "SERVICED_FACILITY"],
      !airportId.isEmpty
    else { return }

    guard let freqString: String = try? t[optional: "FREQ"],
      let freqUse: String = try? t[optional: "FREQ_USE"]
    else { return }

    // Parse frequency using the same method as TXT parser
    guard let frequency = FixedWidthTransformer.parseFrequency(freqString) else { return }

    // FRQ.csv contains many frequency types (navaids, AWOS stations, etc.)
    // We only extract UNICOM and CTAF for airport records
    switch freqUse.uppercased() {
      case "UNICOM":
        unicomFrequencies[airportId] = frequency
      case "CTAF":
        ctafFrequencies[airportId] = frequency
      default:
        break  // Skip other frequency types (not errors, just not needed for airports)
    }
  }

  private func parseARFFCapability(_ ARFFString: String?) throws -> Airport.ARFFCapability? {
    guard let ARFFString, !ARFFString.isEmpty else { return nil }

    // Parse space-separated ARFF string: "CLASS INDEX SERVICE MM/YYYY"
    let parts = ARFFString.split(separator: " ").map { String($0) }
    guard parts.count >= 4 else { return nil }

    guard let ARFFClass = Airport.ARFFCapability.Class(rawValue: parts[0]) else {
      throw CSVParserError.invalidValueInColumn(parts[0], column: "ARFF_CERT_TYPE_DATE")
    }
    guard let ARFFIndex = Airport.ARFFCapability.Index(rawValue: parts[1]) else {
      throw CSVParserError.invalidValueInColumn(parts[1], column: "ARFF_CERT_TYPE_DATE")
    }
    guard let ARFFService = Airport.ARFFCapability.AirService(rawValue: parts[2]) else {
      throw CSVParserError.invalidValueInColumn(parts[2], column: "ARFF_CERT_TYPE_DATE")
    }
    guard let ARFFDateComponents = DateFormat.monthYear.parse(parts[3]) else {
      throw CSVParserError.invalidValueInColumn(parts[3], column: "ARFF_CERT_TYPE_DATE")
    }

    return Airport.ARFFCapability(
      class: ARFFClass,
      index: ARFFIndex,
      airService: ARFFService,
      certificationDateComponents: ARFFDateComponents
    )
  }

  // MARK: - Runway Parsing

  private func parseRunwayRecord(_ row: CSVRow) throws {
    let t = try runwayTransformer.applyTo(row)

    let siteNo: String = try t["SITE_NO"]
    let siteTypeCode: String = try t["SITE_TYPE_CODE"]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard airports[compositeId] != nil else { return }

    let runwayId: String = try t["RWY_ID"]
    let length: UInt? = try t[optional: "RWY_LEN"]
    let width: UInt? = try t[optional: "RWY_WIDTH"]

    // Parse surface type and condition
    let surfaceCode: String = (try? t[optional: "SURFACE_TYPE_CODE"]) ?? ""
    let conditionCode: String? = try t[optional: "COND"]
    let (materials, condition) = parseRunwaySurface(surfaceCode, conditionCode: conditionCode)

    // Parse treatment
    let treatmentCode: String? = try t[optional: "TREATMENT_CODE"]
    let treatment: Runway.Treatment? =
      if let code = treatmentCode, code != "NONE" {
        Runway.Treatment(rawValue: code)
      } else {
        nil
      }

    // Parse pavement classification
    let pavementClassification = try parsePavementClassification(t)

    // Parse edge lights
    let edgeLightCode: String? = try t[optional: "RWY_LGT_CODE"]
    let edgeLightsIntensity: Runway.EdgeLightIntensity? =
      if let code = edgeLightCode {
        Runway.EdgeLightIntensity.for(code)
      } else {
        nil
      }

    // Parse length source info
    let lengthSource: String? = try t[optional: "RWY_LEN_SOURCE"]
    let lengthSourceDateComponents: DateComponents? = try t[optional: "LENGTH_SOURCE_DATE"]

    // Parse weight bearing capacities (values are in thousands of lbs, may be decimal like 12.5)
    let singleWheelWeightKlb: UInt? = (try? t[optional: "GROSS_WT_SW"] as Double?).flatMap {
      $0.map { UInt($0 * 1000) }
    }
    let dualWheelWeightKlb: UInt? = (try? t[optional: "GROSS_WT_DW"] as Double?).flatMap {
      $0.map { UInt($0 * 1000) }
    }
    let tandemDualWheelWeightKlb: UInt? = (try? t[optional: "GROSS_WT_DTW"] as Double?).flatMap {
      $0.map { UInt($0 * 1000) }
    }
    let doubleTandemDualWheelWeightKlb: UInt? =
      (try? t[optional: "GROSS_WT_DDTW"] as Double?).flatMap {
        $0.map { UInt($0 * 1000) }
      }

    // Create a placeholder RunwayEnd - will be populated later from APT_RWY_END.csv
    let placeholderEnd = RunwayEnd(
      id: runwayId.split(separator: "/").first.map(String.init) ?? runwayId,
      heading: nil,
      instrumentLandingSystem: nil,
      rightTraffic: nil,
      marking: nil,
      markingCondition: nil,
      threshold: nil,
      thresholdCrossingHeightFtAGL: nil,
      visualGlidepathDeg: nil,
      displacedThreshold: nil,
      thresholdDisplacementFt: nil,
      touchdownZoneElevationFtMSL: nil,
      gradientPct: nil,
      TORAFt: nil,
      TODAFt: nil,
      ASDAFt: nil,
      LDAFt: nil,
      LAHSO: nil,
      visualGlideslopeIndicator: nil,
      RVRSensors: [],
      hasRVV: nil,
      approachLighting: nil,
      hasREIL: nil,
      hasCenterlineLighting: nil,
      hasEndTouchdownLighting: nil,
      controllingObject: nil,
      positionSource: nil,
      positionSourceDateComponents: nil,
      elevationSource: nil,
      elevationSourceDateComponents: nil,
      displacedThresholdPositionSource: nil,
      displacedThresholdPositionSourceDateComponents: nil,
      displacedThresholdElevationSource: nil,
      displacedThresholdElevationSourceDateComponents: nil,
      touchdownZoneElevationSource: nil,
      touchdownZoneElevationSourceDateComponents: nil
    )

    let runway = Runway(
      identification: runwayId,
      lengthFt: length,
      widthFt: width,
      lengthSource: lengthSource,
      lengthSourceDateComponents: lengthSourceDateComponents,
      materials: materials,
      condition: condition,
      treatment: treatment,
      pavementClassification: pavementClassification,
      edgeLightsIntensity: edgeLightsIntensity,
      baseEnd: placeholderEnd,
      reciprocalEnd: nil,
      singleWheelWeightBearingCapacityKlb: singleWheelWeightKlb,
      dualWheelWeightBearingCapacityKlb: dualWheelWeightKlb,
      tandemDualWheelWeightBearingCapacityKlb: tandemDualWheelWeightKlb,
      doubleTandemDualWheelWeightBearingCapacityKlb: doubleTandemDualWheelWeightKlb
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

  private func parsePavementClassification(_ t: TransformedRow) throws
    -> Runway.PavementClassification?
  {
    guard let pcnNumber: Int = try t[optional: "PCN"] else { return nil }

    guard
      let typeCode: String = try t[optional: "PAVEMENT_TYPE_CODE"],
      let type = Runway.PavementClassification.Classification(rawValue: typeCode)
    else { return nil }

    guard
      let strengthCode: String = try t[optional: "SUBGRADE_STRENGTH_CODE"],
      let strength = Runway.PavementClassification.SubgradeStrengthCategory(rawValue: strengthCode)
    else { return nil }

    guard
      let tirePressureCode: String = try t[optional: "TIRE_PRES_CODE"],
      let tirePressure = Runway.PavementClassification.TirePressureLimit(rawValue: tirePressureCode)
    else { return nil }

    guard
      let determinationCode: String = try t[optional: "DTRM_METHOD_CODE"],
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

  private func parseRunwayEndRecord(_ row: CSVRow) throws {
    let t = try runwayEndTransformer.applyTo(row)

    let siteNo: String = try t["SITE_NO"]
    let siteTypeCode: String = try t["SITE_TYPE_CODE"]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard let airport = airports[compositeId] else { return }

    let runwayId: String = try t["RWY_ID"]
    let runwayEndId: String = try t["RWY_END_ID"]

    // Find the runway for this end
    guard
      let runwayIndex = airports[compositeId]!.runways.firstIndex(where: {
        $0.identification == runwayId
      })
    else { return }

    let runwayEnd = try buildRunwayEnd(
      from: t,
      magneticVariation: airport.magneticVariationDeg
    )

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

  private func buildRunwayEnd(from t: TransformedRow, magneticVariation: Int?) throws -> RunwayEnd {
    let endId: String = try t["RWY_END_ID"]

    // Convert true heading to Bearing<UInt>
    let heading: Bearing<UInt>? = {
      guard let value: Int = try? t[optional: "TRUE_ALIGNMENT"] else { return nil }
      return Bearing(UInt(value), reference: .true, magneticVariationDeg: magneticVariation ?? 0)
    }()

    // Parse ILS type
    let ILSCode: String? = try t[optional: "ILS_TYPE"]
    let instrumentLandingSystem: RunwayEnd.InstrumentLandingSystem? =
      if let code = ILSCode {
        RunwayEnd.InstrumentLandingSystem.for(code)
      } else {
        nil
      }

    // Parse right traffic
    let rightTraffic = try parseYNFlag("RIGHT_HAND_TRAFFIC_PAT_FLAG", from: t)

    // Parse marking and condition
    let markingCode: String? = try t[optional: "RWY_MARKING_TYPE_CODE"]
    let marking: RunwayEnd.Marking? =
      if let code = markingCode, code != "NONE" {
        RunwayEnd.Marking(rawValue: code)
      } else {
        nil
      }

    let markingCondCode: String? = try t[optional: "RWY_MARKING_COND"]
    let markingCondition: RunwayEnd.MarkingCondition? =
      if let code = markingCondCode {
        RunwayEnd.MarkingCondition.for(code)
      } else {
        nil
      }

    // Parse threshold location
    let threshold = try parseThresholdLocation(t)

    // Parse threshold crossing height
    let thresholdCrossingHeight: UInt? = try t[optional: "THR_CROSSING_HGT"]

    // Parse visual glidepath angle (CSV stores degrees directly)
    let visualGlidepath: Float? = try t[optional: "VISUAL_GLIDE_PATH_ANGLE"]

    // Parse displaced threshold
    let displacedThreshold = try parseDisplacedThresholdLocation(t)

    // Parse threshold displacement distance
    let thresholdDisplacement: UInt? = try t[optional: "DISPLACED_THR_LEN"]

    // Parse TDZE
    let touchdownZoneElevation: Float? = try t[optional: "TDZ_ELEV"]

    // Parse VGSI
    let vgsiCode: String? = try t[optional: "VGSI_CODE"]
    let visualGlideslopeIndicator: RunwayEnd.VisualGlideslopeIndicator? =
      if let code = vgsiCode {
        try parseVGSI(code)
      } else {
        nil
      }

    // Parse RVR sensors
    let rvrCode: String = (try? t[optional: "RWY_VISUAL_RANGE_EQUIP_CODE"]) ?? ""
    let RVRSensors = parseRVRSensors(rvrCode)

    // Parse RVV
    let hasRVV = try parseYNFlag("RWY_VSBY_VALUE_EQUIP_FLAG", from: t)

    // Parse approach lighting
    let approachLightCode: String? = try t[optional: "APCH_LGT_SYSTEM_CODE"]
    let approachLighting: RunwayEnd.ApproachLighting? =
      if let code = approachLightCode, code != "NONE" {
        RunwayEnd.ApproachLighting(rawValue: code)
      } else {
        nil
      }

    // Parse REIL
    let hasREIL = try parseYNFlag("RWY_END_LGTS_FLAG", from: t)

    // Parse centerline lighting
    let hasCenterlineLighting = try parseYNFlag("CNTRLN_LGTS_AVBL_FLAG", from: t)

    // Parse TDZ lighting
    let hasEndTouchdownLighting = try parseYNFlag("TDZ_LGT_AVBL_FLAG", from: t)

    // Parse controlling object
    let controllingObject = try parseControllingObject(t)

    // Parse gradient
    let gradient = try parseGradient(t)

    // Parse TORA/TODA/ASDA/LDA
    let TORA: UInt? = try t[optional: "TKOF_RUN_AVBL"]
    let TODA: UInt? = try t[optional: "TKOF_DIST_AVBL"]
    let ASDA: UInt? = try t[optional: "ACLT_STOP_DIST_AVBL"]
    let LDA: UInt? = try t[optional: "LNDG_DIST_AVBL"]

    // Parse LAHSO
    let LAHSO = try parseLAHSO(t)

    // Parse source info
    let positionSource: String? = try t[optional: "RWY_END_PSN_SOURCE"]
    let positionSourceDateComponents: DateComponents? = try t[optional: "RWY_END_PSN_DATE"]

    let elevationSource: String? = try t[optional: "RWY_END_ELEV_SOURCE"]
    let elevationSourceDateComponents: DateComponents? = try t[optional: "RWY_END_ELEV_DATE"]

    let displacedThresholdPositionSource: String? = try t[optional: "DSPL_THR_PSN_SOURCE"]
    let displacedThresholdPositionSourceDateComponents: DateComponents? = try t[
      optional: "RWY_END_DSPL_THR_PSN_DATE"
    ]

    let displacedThresholdElevationSource: String? = try t[optional: "DSPL_THR_ELEV_SOURCE"]
    let displacedThresholdElevationSourceDateComponents: DateComponents? = try t[
      optional: "RWY_END_DSPL_THR_ELEV_DATE"
    ]

    let touchdownZoneElevationSource: String? = try t[optional: "TDZ_ELEV_SOURCE"]
    let touchdownZoneElevationSourceDateComponents: DateComponents? = try t[
      optional: "RWY_END_TDZ_ELEV_DATE"
    ]

    return RunwayEnd(
      id: endId,
      heading: heading,
      instrumentLandingSystem: instrumentLandingSystem,
      rightTraffic: rightTraffic,
      marking: marking,
      markingCondition: markingCondition,
      threshold: threshold,
      thresholdCrossingHeightFtAGL: thresholdCrossingHeight,
      visualGlidepathDeg: visualGlidepath,
      displacedThreshold: displacedThreshold,
      thresholdDisplacementFt: thresholdDisplacement,
      touchdownZoneElevationFtMSL: touchdownZoneElevation,
      gradientPct: gradient,
      TORAFt: TORA,
      TODAFt: TODA,
      ASDAFt: ASDA,
      LDAFt: LDA,
      LAHSO: LAHSO,
      visualGlideslopeIndicator: visualGlideslopeIndicator,
      RVRSensors: RVRSensors,
      hasRVV: hasRVV,
      approachLighting: approachLighting,
      hasREIL: hasREIL,
      hasCenterlineLighting: hasCenterlineLighting,
      hasEndTouchdownLighting: hasEndTouchdownLighting,
      controllingObject: controllingObject,
      positionSource: positionSource,
      positionSourceDateComponents: positionSourceDateComponents,
      elevationSource: elevationSource,
      elevationSourceDateComponents: elevationSourceDateComponents,
      displacedThresholdPositionSource: displacedThresholdPositionSource,
      displacedThresholdPositionSourceDateComponents:
        displacedThresholdPositionSourceDateComponents,
      displacedThresholdElevationSource: displacedThresholdElevationSource,
      displacedThresholdElevationSourceDateComponents:
        displacedThresholdElevationSourceDateComponents,
      touchdownZoneElevationSource: touchdownZoneElevationSource,
      touchdownZoneElevationSourceDateComponents: touchdownZoneElevationSourceDateComponents
    )
  }

  private func parseThresholdLocation(_ t: TransformedRow) throws -> Location? {
    guard let latDecimal: Float = try t[optional: "LAT_DECIMAL"],
      let longDecimal: Float = try t[optional: "LONG_DECIMAL"]
    else { return nil }

    // Convert decimal degrees to arc-seconds for Location
    let latArcSec = latDecimal * 3600
    let longArcSec = longDecimal * 3600
    let elevation: Float? = try t[optional: "RWY_END_ELEV"]

    return Location(
      latitudeArcsec: latArcSec,
      longitudeArcsec: longArcSec,
      elevationFtMSL: elevation
    )
  }

  private func parseDisplacedThresholdLocation(_ t: TransformedRow) throws -> Location? {
    guard
      let latDecimal: Float = try t[optional: "LAT_DISPLACED_THR_DECIMAL"],
      let longDecimal: Float = try t[optional: "LONG_DISPLACED_THR_DECIMAL"]
    else { return nil }

    // Convert decimal degrees to arc-seconds for Location
    let latArcSec = latDecimal * 3600
    let longArcSec = longDecimal * 3600
    let elevation: Float? = try t[optional: "DISPLACED_THR_ELEV"]

    return Location(
      latitudeArcsec: latArcSec,
      longitudeArcsec: longArcSec,
      elevationFtMSL: elevation
    )
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

  private func parseControllingObject(_ t: TransformedRow) throws -> RunwayEnd.ControllingObject? {
    guard let categoryCode: String = try t[optional: "OBSTN_TYPE"] else {
      return nil
    }

    let category = RunwayEnd.ControllingObject.Category(rawValue: categoryCode)

    // Parse markings
    var markings = [RunwayEnd.ControllingObject.Marking]()
    if let markingCode: String = try t[optional: "OBSTN_MRKD_CODE"] {
      for char in markingCode {
        if let marking = RunwayEnd.ControllingObject.Marking(rawValue: String(char)) {
          markings.append(marking)
        }
      }
    }

    let runwayCategory: String? = try t[optional: "FAR_PART_77_CODE"]
    let clearanceSlope: UInt? = try t[optional: "OBSTN_CLNC_SLOPE"]
    let heightAboveRunway: UInt? = try t[optional: "OBSTN_HGT"]
    let distanceFromRunway: UInt? = try t[optional: "DIST_FROM_THR"]

    // Parse offset
    let offsetFromCenterline = try parseOffset(t)

    return RunwayEnd.ControllingObject(
      category: category,
      markings: markings,
      runwayCategory: runwayCategory,
      clearanceSlopeRatio: clearanceSlope,
      heightAboveRunwayFtAGL: heightAboveRunway,
      distanceFromRunwayFt: distanceFromRunway,
      offsetFromCenterline: offsetFromCenterline
    )
  }

  private func parseOffset(_ t: TransformedRow) throws -> Offset? {
    guard let distance: UInt = try t[optional: "CNTRLN_OFFSET"] else { return nil }
    let directionCode: String? = try t[optional: "CNTRLN_DIR_CODE"]

    let direction: Offset.Direction =
      if let code = directionCode, let dir = Offset.Direction.from(string: code) {
        dir
      } else {
        .left  // Default fallback
      }

    return Offset(distanceFt: distance, direction: direction)
  }

  private func parseGradient(_ t: TransformedRow) throws -> Float? {
    guard let gradientValue: Float = try t[optional: "RWY_GRAD"] else {
      return nil
    }

    var gradient = gradientValue
    let directionCode: String? = try t[optional: "RWY_GRAD_DIRECTION"]
    if directionCode == "DOWN" {
      gradient *= -1
    }

    return gradient
  }

  private func parseLAHSO(_ t: TransformedRow) throws -> RunwayEnd.LAHSOPoint? {
    guard let availableDistance: UInt = try t[optional: "LAHSO_ALD"] else {
      return nil
    }

    let intersectingRunwayId: String? = try t[optional: "RWY_END_INTERSECT_LAHSO"]
    let definingEntity: String? = try t[optional: "LAHSO_DESC"]

    // Parse LAHSO position
    var position: Location?
    if let latDecimal: Float = try t[optional: "LAT_LAHSO_DECIMAL"],
      let longDecimal: Float = try t[optional: "LONG_LAHSO_DECIMAL"]
    {
      let latArcSec = latDecimal * 3600
      let longArcSec = longDecimal * 3600
      position = Location(
        latitudeArcsec: latArcSec,
        longitudeArcsec: longArcSec,
        elevationFtMSL: nil
      )
    }

    let positionSource: String? = try t[optional: "LAHSO_PSN_SOURCE"]
    let positionSourceDate: DateComponents? = try t[optional: "RWY_END_LAHSO_PSN_DATE"]

    return RunwayEnd.LAHSOPoint(
      availableDistanceFt: availableDistance,
      intersectingRunwayId: intersectingRunwayId,
      definingEntity: definingEntity,
      position: position,
      positionSource: positionSource,
      positionSourceDateComponents: positionSourceDate
    )
  }

  // MARK: - Attendance Schedule Parsing

  private func parseAttendanceRecord(_ row: CSVRow) throws {
    let siteNo = try row["SITE_NO"]
    let siteTypeCode = try row["SITE_TYPE_CODE"]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard airports[compositeId] != nil else { return }

    let month = row[ifExists: "MONTH"] ?? ""
    let day = row[ifExists: "DAY"] ?? ""
    let hour = row[ifExists: "HOUR"] ?? ""

    // Handle unattended entries as custom schedules (like TXT parser does)
    let schedule: AttendanceSchedule
    if month == "UNATNDD" || month == "UNATTND" {
      schedule = .custom(month)
    } else if !month.isEmpty && !day.isEmpty && !hour.isEmpty {
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

  private func parseRemarkRecord(_ row: CSVRow) throws {
    let siteNo = try row["SITE_NO"]
    let siteTypeCode = try row["SITE_TYPE_CODE"]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard airports[compositeId] != nil else { return }

    let tabName = row[ifExists: "TAB_NAME"] ?? ""
    let element = row[ifExists: "ELEMENT"] ?? ""
    let remark = try row["REMARK"]

    if remark.isEmpty { return }

    switch tabName {
      case "AIRPORT", "AIRPORT_ATTEND_SCHED", "AIRPORT_SERVICE", "ARRESTING_DEVICE":
        // Airport-level remarks
        airports[compositeId]!.remarks.append(.general(remark))

      case "RUNWAY", "RUNWAY_SURFACE_TYPE":
        // Runway-specific remarks
        if let runwayIndex = airports[compositeId]!.runways.firstIndex(where: {
          $0.identification == element
        }) {
          airports[compositeId]!.runways[runwayIndex].remarks.append(.general(remark))
        }

      case "RUNWAY_END", "RUNWAY_END_OBSTN":
        // Runway end-specific remarks (including obstruction remarks)
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
        // Legacy element number codes (A110-*, A17-M2, A18, A52-H1, A81-APT, E111)
        // are added as general remarks
        if tabName.hasPrefix("A") || tabName.hasPrefix("E") {
          airports[compositeId]!.remarks.append(.general(remark))
        } else {
          throw ParserError.unknownRecordEnumValue(tabName)
        }
    }
  }

  @discardableResult
  private func updateRunwayEnd(
    _ identifier: String,
    inAirport airport: inout Airport,
    process: (inout RunwayEnd) -> Void
  ) -> Bool {
    for (index, runway) in airport.runways.enumerated() {
      if runway.baseEnd.id == identifier {
        var end = runway.baseEnd
        process(&end)
        airport.runways[index].baseEnd = end
        return true
      }
      if let reciprocal = runway.reciprocalEnd, reciprocal.id == identifier {
        var end = reciprocal
        process(&end)
        airport.runways[index].reciprocalEnd = end
        return true
      }
    }
    return false
  }

  // MARK: - Arresting Systems Parsing

  private func parseArrestingSystemRecord(_ row: CSVRow) throws {
    let siteNo = try row["SITE_NO"]
    let siteTypeCode = try row["SITE_TYPE_CODE"]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard airports[compositeId] != nil else { return }

    let runwayId = try row["RWY_ID"]
    let runwayEndId = try row["RWY_END_ID"]
    let deviceCode = row[ifExists: "ARREST_DEVICE_CODE"] ?? ""

    if deviceCode.isEmpty { return }

    // Find the runway
    guard
      let runwayIndex = airports[compositeId]!.runways.firstIndex(where: {
        $0.identification == runwayId
      })
    else { return }

    let runway = airports[compositeId]!.runways[runwayIndex]

    // Determine which end this arresting system belongs to
    if runway.baseEnd.id == runwayEndId {
      airports[compositeId]!.runways[runwayIndex].baseEnd.arrestingSystems.append(deviceCode)
    } else if runway.reciprocalEnd?.id == runwayEndId {
      airports[compositeId]!.runways[runwayIndex].reciprocalEnd!.arrestingSystems.append(deviceCode)
    }
  }

  // MARK: - Contacts Parsing

  private func parseContactRecord(_ row: CSVRow) throws {
    let siteNo = try row["SITE_NO"]
    let siteTypeCode = try row["SITE_TYPE_CODE"]
    let compositeId = "\(siteNo)*\(siteTypeCode)"

    guard airports[compositeId] != nil else { return }

    let title = try row["TITLE"]
    let name = try row["NAME"]

    if name.isEmpty { return }

    let address1 = row[ifExists: "ADDRESS1"]
    let address2 = row[ifExists: "ADDRESS2"]
    let city = row[ifExists: "TITLE_CITY"] ?? ""
    let state = row[ifExists: "STATE"] ?? ""
    let zipCode = row[ifExists: "ZIP_CODE"] ?? ""
    let zipPlusFour = row[ifExists: "ZIP_PLUS_FOUR"]
    let phone = row[ifExists: "PHONE_NO"]

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

  /// Creates a Location from optional lat/lon (decimal degrees), throwing if only one is present.
  /// Converts decimal degrees to arc-seconds for Location storage.
  private func makeLocation(
    latitude: Float?,
    longitude: Float?,
    elevation: Float?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        // Convert decimal degrees to arc-seconds (multiply by 3600)
        return Location(
          latitudeArcsec: lat * 3600,
          longitudeArcsec: lon * 3600,
          elevationFtMSL: elevation
        )
      case (.none, .none):
        return nil
      default:
        throw ParserError.invalidLocation(
          latitude: latitude,
          longitude: longitude,
          context: context
        )
    }
  }

  /// Parses a Y/N flag from a TransformedRow column with strict validation.
  private func parseYNFlag(_ column: String, from t: TransformedRow) throws -> Bool? {
    let value: String? = try t[optional: column]
    return try ParserHelpers.parseYNFlag(value, fieldName: column)
  }
}
