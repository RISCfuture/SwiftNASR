import Foundation

enum LIDRecordIdentifier: String {
  case usa = "USA"
  case dod = "DOD"
  case can = "CAN"
}

/// Parser for Location Identifier (LID) files.
///
/// These files contain location identifiers for various aviation facilities.
/// Records are 1039 characters fixed-width with three record types:
/// USA (United States), DOD (Dept of Defense overseas), and CAN (Canadian).
/// This parser currently handles USA records only.
class FixedWidthLocationIdentifierParser: FixedWidthParser {
  typealias RecordIdentifier = LIDRecordIdentifier

  static let type = RecordType.locationIdentifiers
  static let layoutFormatOrder: [LIDRecordIdentifier] = [.usa, .dod, .can]

  var recordTypeRange: Range<UInt> { 1..<4 }
  var formats = [NASRTable]()
  var identifiers = [LocationIdentifier]()

  private let usaTransformer = FixedWidthTransformer([
    .null,  // 0 group sort code (1)
    .null,  // 1 group code (3)
    .string(),  // 2 location identifier (5)
    .string(nullable: .blank),  // 3 FAA region (3)
    .string(nullable: .blank),  // 4 state code (2)
    .string(nullable: .blank),  // 5 city (40)
    .string(nullable: .blank),  // 6 controlling ARTCC (4)
    .string(nullable: .blank),  // 7 controlling ARTCC computer ID (3)
    .string(nullable: .blank),  // 8 landing facility name (50)
    .string(nullable: .blank),  // 9 landing facility type (13)
    .string(nullable: .blank),  // 10 landing facility FSS (4)
    .string(nullable: .blank),  // 11 navaid 1 name (30)
    .string(nullable: .blank),  // 12 navaid 1 type (20)
    .string(nullable: .blank),  // 13 navaid 2 name (30)
    .string(nullable: .blank),  // 14 navaid 2 type (20)
    .string(nullable: .blank),  // 15 navaid 3 name (30)
    .string(nullable: .blank),  // 16 navaid 3 type (20)
    .string(nullable: .blank),  // 17 navaid 4 name (30)
    .string(nullable: .blank),  // 18 navaid 4 type (20)
    .string(nullable: .blank),  // 19 navaid FSS (4)
    .string(nullable: .blank),  // 20 ILS runway end (3)
    .string(nullable: .blank),  // 21 ILS facility type (20)
    .string(nullable: .blank),  // 22 ILS airport identifier (5)
    .string(nullable: .blank),  // 23 ILS airport name (50)
    .string(nullable: .blank),  // 24 ILS FSS (4)
    .string(nullable: .blank),  // 25 FSS name (30)
    .string(nullable: .blank),  // 26 ARTCC name (30)
    .string(nullable: .blank),  // 27 ARTCC facility type (17)
    .boolean(trueValue: "Y", nullable: .blank),  // 28 flight watch indicator (1)
    .string(nullable: .blank),  // 29 other facility name (75)
    .string(nullable: .blank),  // 30 other facility type (15)
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  // 31 effective date (10)
    .null  // 32 blanks (447)
  ])

  func parseValues(_ values: [String], for identifier: LIDRecordIdentifier) throws {
    switch identifier {
      case .usa:
        try parseUSARecord(values)
      case .dod, .can:
        // DOD and CAN records have different formats - not implemented
        break
    }
  }

  private func parseUSARecord(_ values: [String]) throws {
    let transformedValues = try usaTransformer.applyTo(values)

    let identifier = transformedValues[2] as! String
    guard !identifier.isEmpty else {
      throw ParserError.missingRequiredField(field: "identifier", recordType: "USA")
    }

    // Build navaids array from fields 11-18
    var navaids = [LocationIdentifier.NavaidInfo]()
    let navaidPairs = [(11, 12), (13, 14), (15, 16), (17, 18)]
    for (nameIdx, typeIdx) in navaidPairs {
      if let name = transformedValues[nameIdx] as? String, !name.isEmpty {
        let navTypeStr = transformedValues[typeIdx] as? String ?? ""
        let navType = LocationIdentifier.NavaidFacilityType(rawValue: navTypeStr)
        navaids.append(LocationIdentifier.NavaidInfo(name: name, facilityType: navType))
      }
    }

    let landingTypeStr = transformedValues[9] as? String ?? ""
    let ILSTypeStr = transformedValues[21] as? String ?? ""
    let ARTCCTypeStr = transformedValues[27] as? String ?? ""
    let otherTypeStr = transformedValues[30] as? String ?? ""

    let record = LocationIdentifier(
      identifier: identifier,
      groupCode: .usa,
      FAARegion: transformedValues[3] as? String,
      stateCode: transformedValues[4] as? String,
      city: transformedValues[5] as? String,
      controllingARTCC: transformedValues[6] as? String,
      controllingARTCCComputerId: transformedValues[7] as? String,
      landingFacilityName: transformedValues[8] as? String,
      landingFacilityType: LocationIdentifier.LandingFacilityType(rawValue: landingTypeStr),
      landingFacilityFSS: transformedValues[10] as? String,
      navaids: navaids,
      navaidFSS: transformedValues[19] as? String,
      ILSRunwayEnd: transformedValues[20] as? String,
      ilsFacilityType: LocationIdentifier.ILSFacilityType(rawValue: ILSTypeStr),
      ILSAirportIdentifier: transformedValues[22] as? String,
      ILSAirportName: transformedValues[23] as? String,
      ILSFSS: transformedValues[24] as? String,
      FSSName: transformedValues[25] as? String,
      ARTCCName: transformedValues[26] as? String,
      artccFacilityType: LocationIdentifier.ARTCCFacilityType(rawValue: ARTCCTypeStr),
      isFlightWatchStation: transformedValues[28] as? Bool,
      otherFacilityName: transformedValues[29] as? String,
      otherFacilityType: LocationIdentifier.OtherFacilityType(rawValue: otherTypeStr),
      effectiveDateComponents: transformedValues[31] as? DateComponents
    )

    identifiers.append(record)
  }

  func finish(data: NASRData) async {
    await data.finishParsing(locationIdentifiers: identifiers)
  }
}
