import Foundation
import StreamingCSV

/// CSV parser for Location Identifier (LID) files.
///
/// The CSV format stores one facility type per row, unlike the TXT format which
/// aggregates all facility types under a single location identifier record.
/// This parser creates one `LocationIdentifier` record per CSV row.
actor CSVLocationIdentifierParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["LID.csv"]

  var identifiers = [LocationIdentifier]()

  // CSV field indices (0-based):
  // 0: EFF_DATE, 1: COUNTRY_CODE, 2: LOC_ID, 3: REGION_CODE, 4: STATE,
  // 5: CITY, 6: LID_GROUP, 7: FAC_TYPE, 8: FAC_NAME,
  // 9: RESP_ARTCC_ID, 10: ARTCC_COMPUTER_ID, 11: FSS_ID

  private let transformer = CSVTransformer([
    .dateComponents(format: .yearMonthDaySlash, nullable: .blank),  // 0: EFF_DATE
    .string(),  // 1: COUNTRY_CODE
    .string(),  // 2: LOC_ID
    .string(nullable: .blank),  // 3: REGION_CODE
    .string(nullable: .blank),  // 4: STATE (2-letter code)
    .string(nullable: .blank),  // 5: CITY
    .string(),  // 6: LID_GROUP
    .string(nullable: .blank),  // 7: FAC_TYPE
    .string(nullable: .blank),  // 8: FAC_NAME
    .string(nullable: .blank),  // 9: RESP_ARTCC_ID
    .string(nullable: .blank),  // 10: ARTCC_COMPUTER_ID
    .string(nullable: .blank)  // 11: FSS_ID
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    try await parseCSVFile(filename: "LID.csv", expectedFieldCount: 12) { fields in
      guard fields.count >= 12 else { return }

      let transformedValues = try self.transformer.applyTo(fields, indices: Array(0..<12))

      let locID = transformedValues[2] as! String
      guard !locID.isEmpty else { return }

      let countryCode = transformedValues[1] as! String
      let lidGroup = transformedValues[6] as! String
      let facType = transformedValues[7] as? String ?? ""
      let facName = transformedValues[8] as? String
      let fssID = transformedValues[11] as? String

      // Determine group code from country code
      let groupCode = parseGroupCode(countryCode, lidGroup: lidGroup)

      // Initialize all facility-specific fields as nil
      var landingFacilityName: String?
      var landingFacilityType: LocationIdentifier.LandingFacilityType?
      var landingFacilityFSS: String?
      var navaids = [LocationIdentifier.NavaidInfo]()
      var navaidFSS: String?
      var ILSRunwayEnd: String?
      var ilsFacilityType: LocationIdentifier.ILSFacilityType?
      var ILSAirportIdentifier: String?
      var ILSAirportName: String?
      var ILSFSS: String?
      var FSSName: String?
      var ARTCCName: String?
      var artccFacilityType: LocationIdentifier.ARTCCFacilityType?
      let isFlightWatchStation: Bool? = nil
      var otherFacilityName: String?
      var otherFacilityType: LocationIdentifier.OtherFacilityType?

      // Map fields based on LID_GROUP
      switch lidGroup {
        case "LANDING FACILITY":
          landingFacilityName = facName
          landingFacilityType = parseLandingFacilityType(facType)
          landingFacilityFSS = fssID

        case "NAVIGATION AID":
          if let facName {
            let navType = parseNavaidFacilityType(facType)
            navaids.append(LocationIdentifier.NavaidInfo(name: facName, facilityType: navType))
          }
          navaidFSS = fssID

        case "INSTRUMENT LANDING SYSTEM":
          ilsFacilityType = parseILSFacilityType(facType)
          ILSFSS = fssID
          // Parse runway end and airport info from FAC_NAME if available
          if let facName {
            let parsed = parseILSFacilityName(facName)
            ILSRunwayEnd = parsed.runwayEnd
            ILSAirportIdentifier = parsed.airportId
            ILSAirportName = parsed.airportName
          }

        case "CONTROL FACILITY":
          artccFacilityType = parseARTCCFacilityType(facType)
          ARTCCName = facName

        case "FLIGHT SERVICE STATION", "REMOTE COMMUNICATION OUTLET":
          FSSName = facName

        case "WEATHER SENSOR", "WEATHER REPORTING STATION":
          otherFacilityType = .weatherStation
          otherFacilityName = facName

        case "SPECIAL USE RESOURCE":
          otherFacilityType = parseOtherFacilityType(facType)
          otherFacilityName = facName

        case "DOD OVERSEA FACILITY":
          // DOD overseas can be various facility types
          if let parsedLanding = parseLandingFacilityType(facType) {
            landingFacilityName = facName
            landingFacilityType = parsedLanding
            landingFacilityFSS = fssID
          } else if let navType = parseNavaidFacilityType(facType) {
            if let facName {
              navaids.append(LocationIdentifier.NavaidInfo(name: facName, facilityType: navType))
            }
            navaidFSS = fssID
          }

        default:
          // Unknown LID_GROUP, store as other facility
          otherFacilityName = facName
      }

      let record = LocationIdentifier(
        identifier: locID,
        groupCode: groupCode,
        FAARegion: transformedValues[3] as? String,
        stateCode: transformedValues[4] as? String,
        city: transformedValues[5] as? String,
        controllingARTCC: transformedValues[9] as? String,
        controllingARTCCComputerId: transformedValues[10] as? String,
        landingFacilityName: landingFacilityName,
        landingFacilityType: landingFacilityType,
        landingFacilityFSS: landingFacilityFSS,
        navaids: navaids,
        navaidFSS: navaidFSS,
        ILSRunwayEnd: ILSRunwayEnd,
        ilsFacilityType: ilsFacilityType,
        ILSAirportIdentifier: ILSAirportIdentifier,
        ILSAirportName: ILSAirportName,
        ILSFSS: ILSFSS,
        FSSName: FSSName,
        ARTCCName: ARTCCName,
        artccFacilityType: artccFacilityType,
        isFlightWatchStation: isFlightWatchStation,
        otherFacilityName: otherFacilityName,
        otherFacilityType: otherFacilityType,
        effectiveDateComponents: transformedValues[0] as? DateComponents
      )

      self.identifiers.append(record)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(locationIdentifiers: identifiers)
  }

  // MARK: - Private Helpers

  private func parseGroupCode(_ countryCode: String, lidGroup: String) -> LocationIdentifier
    .GroupCode?
  {
    if lidGroup == "DOD OVERSEA FACILITY" {
      return .dod
    }
    switch countryCode.uppercased() {
      case "US": return .usa
      case "CA": return .can
      default: return .usa  // Default to USA for unknown codes
    }
  }

  private func parseLandingFacilityType(_ facType: String) -> LocationIdentifier
    .LandingFacilityType?
  {
    switch facType.uppercased() {
      case "A", "AIRPORT": return .airport
      case "B", "BALLOONPORT": return .balloonport
      case "C", "STOLPORT": return .stolport
      case "G", "GLIDERPORT": return .gliderport
      case "H", "HELIPORT": return .heliport
      case "S", "SEAPLANE BASE": return .seaplaneBase
      case "U", "ULTRALIGHT": return .ultralight
      default: return nil
    }
  }

  private func parseNavaidFacilityType(_ facType: String) -> LocationIdentifier.NavaidFacilityType?
  {
    switch facType.uppercased() {
      case "DME": return .DME
      case "FAN MARKER": return .fanMarker
      case "NDB", "MARINE NDB": return .NDB
      case "NDB/DME": return .NDB_DME
      case "TACAN": return .TACAN
      case "VOR": return .VOR
      case "VOR/DME": return .VOR_DME
      case "VORTAC": return .VORTAC
      case "VOT": return .VOT
      default: return nil
    }
  }

  private func parseILSFacilityType(_ facType: String) -> LocationIdentifier.ILSFacilityType? {
    switch facType.uppercased() {
      case "LS", "ILS": return .ILS
      case "LD", "ILS/DME": return .ILS_DME
      case "LC", "LOCALIZER", "LOC": return .localizer
      case "LG", "LOC/GS": return .LOC_GS
      case "LA", "LDA": return .LDA
      case "LE", "LDA/DME": return .LDA_DME
      case "SD", "SDF": return .SDF
      case "SF", "SDF/DME", "SF/DME": return .SDF_DME
      case "DD", "LOC/DME": return .LOC_DME
      default: return nil
    }
  }

  private func parseARTCCFacilityType(_ facType: String) -> LocationIdentifier.ARTCCFacilityType? {
    switch facType.uppercased() {
      case "ARTCC": return .ARTCC
      case "CERAP": return .CERAP
      // TRACON and BASE OPS are not in the enum
      default: return nil
    }
  }

  private func parseOtherFacilityType(_ facType: String) -> LocationIdentifier.OtherFacilityType? {
    switch facType.uppercased() {
      case "ADMINISTRATIVE SERVICES", "ADMINISTRATIVE SERVICES(2)": return .administrative
      case "GEOGRAPHIC REFERENCE POINT", "GEOREF": return .georef
      case "SPECIAL USAGE", "SPECIAL USE": return .specialUse
      case "WEATHER STATION", "WEATHER STATION(2)", "WEATHER SERVICE OFFICE": return .weatherStation
      default: return nil
    }
  }

  /// Parse ILS facility name to extract runway end, airport ID, and airport name.
  /// Format: "AIRPORT_NAME(AIRPORT_ID) ILS RWY XX" or similar variations
  private func parseILSFacilityName(_ name: String) -> (
    runwayEnd: String?, airportId: String?, airportName: String?
  ) {
    // Try to extract airport ID from parentheses
    var airportId: String?
    var airportName: String?
    var runwayEnd: String?

    // Pattern: "AIRPORT NAME(ABC) ... RWY XX" or "AIRPORT NAME(ABC) ... RWY XXL/R"
    if let parenStart = name.firstIndex(of: "("),
      let parenEnd = name.firstIndex(of: ")"),
      parenStart < parenEnd
    {
      airportId = String(name[name.index(after: parenStart)..<parenEnd])
      airportName = String(name[..<parenStart]).trimmingCharacters(in: .whitespaces)
    }

    // Try to find runway designation
    if let rwyRange = name.range(of: "RWY ", options: .caseInsensitive) {
      let afterRwy = name[rwyRange.upperBound...]
      // Take runway designation (e.g., "28R", "18", "36L")
      let components = afterRwy.split(separator: " ", maxSplits: 1)
      if let rwy = components.first {
        runwayEnd = String(rwy)
      }
    }

    return (runwayEnd, airportId, airportName)
  }
}
