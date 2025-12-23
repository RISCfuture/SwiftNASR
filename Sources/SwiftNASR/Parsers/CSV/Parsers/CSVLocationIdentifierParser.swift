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

  private let transformer = CSVTransformer([
    .init("EFF_DATE", .dateComponents(format: .yearMonthDaySlash, nullable: .blank)),
    .init("COUNTRY_CODE", .string()),
    .init("LOC_ID", .string()),
    .init("REGION_CODE", .string(nullable: .blank)),
    .init("STATE", .string(nullable: .blank)),
    .init("CITY", .string(nullable: .blank)),
    .init("LID_GROUP", .string()),
    .init("FAC_TYPE", .string(nullable: .blank)),
    .init("FAC_NAME", .string(nullable: .blank)),
    .init("RESP_ARTCC_ID", .string(nullable: .blank)),
    .init("ARTCC_COMPUTER_ID", .string(nullable: .blank)),
    .init("FSS_ID", .string(nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    try await parseCSVFile(
      filename: "LID.csv",
      requiredColumns: ["LOC_ID", "COUNTRY_CODE", "LID_GROUP"]
    ) { row in
      let t = try self.transformer.applyTo(row)

      let locID: String = try t["LOC_ID"]
      guard !locID.isEmpty else { return }

      let countryCode: String = try t["COUNTRY_CODE"]
      let lidGroup: String = try t["LID_GROUP"]
      let facType: String = try t[optional: "FAC_TYPE"] ?? ""
      let facName: String? = try t[optional: "FAC_NAME"]
      let fssID: String? = try t[optional: "FSS_ID"]

      // Determine group code from country code
      let groupCode = try parseGroupCode(countryCode, lidGroup: lidGroup)

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
          landingFacilityType = try parseLandingFacilityType(facType)
          landingFacilityFSS = fssID

        case "NAVIGATION AID":
          if let facName {
            let navType = try parseNavaidFacilityType(facType)
            navaids.append(LocationIdentifier.NavaidInfo(name: facName, facilityType: navType))
          }
          navaidFSS = fssID

        case "INSTRUMENT LANDING SYSTEM":
          ilsFacilityType = try parseILSFacilityType(facType)
          ILSFSS = fssID
          // Parse runway end and airport info from FAC_NAME if available
          if let facName {
            let parsed = parseILSFacilityName(facName)
            ILSRunwayEnd = parsed.runwayEnd
            ILSAirportIdentifier = parsed.airportId
            ILSAirportName = parsed.airportName
          }

        case "CONTROL FACILITY":
          artccFacilityType = try parseARTCCFacilityType(facType)
          ARTCCName = facName

        case "FLIGHT SERVICE STATION", "REMOTE COMMUNICATION OUTLET":
          FSSName = facName

        case "WEATHER SENSOR", "WEATHER REPORTING STATION":
          otherFacilityType = .weatherStation
          otherFacilityName = facName

        case "SPECIAL USE RESOURCE":
          otherFacilityType = try parseOtherFacilityType(facType)
          otherFacilityName = facName

        case "DOD OVERSEA FACILITY":
          // DOD overseas can be various facility types - try each type until one matches
          if let parsedLanding = tryParseLandingFacilityType(facType) {
            landingFacilityName = facName
            landingFacilityType = parsedLanding
            landingFacilityFSS = fssID
          } else if let navType = tryParseNavaidFacilityType(facType) {
            if let facName {
              navaids.append(LocationIdentifier.NavaidInfo(name: facName, facilityType: navType))
            }
            navaidFSS = fssID
          } else {
            throw ParserError.unknownRecordEnumValue(facType)
          }

        default:
          throw ParserError.unknownRecordEnumValue(lidGroup)
      }

      let record = LocationIdentifier(
        identifier: locID,
        groupCode: groupCode,
        FAARegion: try t[optional: "REGION_CODE"],
        stateCode: try t[optional: "STATE"],
        city: try t[optional: "CITY"],
        controllingARTCC: try t[optional: "RESP_ARTCC_ID"],
        controllingARTCCComputerId: try t[optional: "ARTCC_COMPUTER_ID"],
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
        effectiveDateComponents: try t[optional: "EFF_DATE"]
      )

      self.identifiers.append(record)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(locationIdentifiers: identifiers)
  }

  // MARK: - Private Helpers

  private func parseGroupCode(_ countryCode: String, lidGroup: String) throws
    -> LocationIdentifier
    .GroupCode
  {
    if lidGroup == "DOD OVERSEA FACILITY" {
      return .DOD
    }
    switch countryCode.uppercased() {
      case "US": return .USA
      case "CA": return .canada
      case "MH": return .marshallIslands
      case "PW": return .palau
      case "BM": return .bermuda
      case "BS": return .bahamas
      case "TC": return .turksAndCaicos
      case "FM": return .micronesia
      case "TQ": return .USMinorOutlyingIslands
      case "PO": return .azores
      default:
        throw ParserError.unknownRecordEnumValue(countryCode)
    }
  }

  private func parseLandingFacilityType(_ facType: String) throws
    -> LocationIdentifier
    .LandingFacilityType
  {
    switch facType.uppercased() {
      case "A", "AIRPORT": return .airport
      case "B", "BALLOONPORT": return .balloonport
      case "C", "STOLPORT": return .stolport
      case "G", "GLIDERPORT": return .gliderport
      case "H", "HELIPORT": return .heliport
      case "S", "SEAPLANE BASE": return .seaplaneBase
      case "U", "ULTRALIGHT": return .ultralight
      default: throw ParserError.unknownRecordEnumValue(facType)
    }
  }

  private func tryParseLandingFacilityType(_ facType: String) -> LocationIdentifier
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

  private func parseNavaidFacilityType(_ facType: String) throws
    -> LocationIdentifier
    .NavaidFacilityType
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
      default: throw ParserError.unknownRecordEnumValue(facType)
    }
  }

  private func tryParseNavaidFacilityType(_ facType: String) -> LocationIdentifier
    .NavaidFacilityType?
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

  private func parseILSFacilityType(_ facType: String) throws -> LocationIdentifier.ILSFacilityType
  {
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
      default: throw ParserError.unknownRecordEnumValue(facType)
    }
  }

  private func parseARTCCFacilityType(_ facType: String) throws -> LocationIdentifier
    .ARTCCFacilityType?
  {
    switch facType.uppercased() {
      case "ARTCC": return .ARTCC
      case "CERAP": return .CERAP
      case "BASE OPS": return .baseOps
      // Terminal facility types are valid control facilities but not ARTCCs
      case "TRACON", "ATCT", "NON-ATCT", "ATCT-TRACON", "ATCT-A/C",
        "ATCT-RAPCON", "ATCT-RATCF", "ATCT-TRACAB", "TRACAB":
        return nil
      default: throw ParserError.unknownRecordEnumValue(facType)
    }
  }

  private func parseOtherFacilityType(_ facType: String) throws
    -> LocationIdentifier
    .OtherFacilityType
  {
    switch facType.uppercased() {
      case "ADMINISTRATIVE SERVICES", "ADMINISTRATIVE SERVICES(2)": return .administrative
      case "GEOGRAPHIC REFERENCE POINT", "GEOREF": return .georef
      case "SPECIAL USAGE", "SPECIAL USE": return .specialUse
      case "WEATHER STATION", "WEATHER STATION(2)", "WEATHER SERVICE OFFICE": return .weatherStation
      default: throw ParserError.unknownRecordEnumValue(facType)
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
