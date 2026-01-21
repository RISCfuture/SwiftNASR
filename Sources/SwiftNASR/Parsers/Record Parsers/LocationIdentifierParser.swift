import Foundation

enum LIDRecordIdentifier: String {
  case USA = "USA"
  case DOD = "DOD"
  case canada = "CAN"
}

/// Parser for Location Identifier (LID) files.
///
/// These files contain location identifiers for various aviation facilities.
/// Records are 1039 characters fixed-width with three record types:
/// USA (United States), DOD (Dept of Defense overseas), and CAN (Canadian).
/// This parser currently handles USA records only.
actor FixedWidthLocationIdentifierParser: FixedWidthParser {
  typealias RecordIdentifier = LIDRecordIdentifier

  static let type = RecordType.locationIdentifiers
  static let layoutFormatOrder: [LIDRecordIdentifier] = [.USA, .DOD, .canada]

  var recordTypeRange: Range<UInt> { 1..<4 }
  var formats = [NASRTable]()
  var identifiers = [LocationIdentifier]()

  private let usaTransformer = ByteTransformer([
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

  func parseValues(_ values: [ArraySlice<UInt8>], for identifier: LIDRecordIdentifier) throws {
    switch identifier {
      case .USA:
        try parseUSARecord(values)
      case .DOD, .canada:
        // DOD and Canada records have different formats - not implemented
        break
    }
  }

  private func parseUSARecord(_ values: [ArraySlice<UInt8>]) throws {
    let t = try usaTransformer.applyTo(values)

    let identifier: String = try t[2]
    guard !identifier.isEmpty else {
      throw ParserError.missingRequiredField(field: "identifier", recordType: "USA")
    }

    // Build navaids array from fields 11-18
    var navaids = [LocationIdentifier.NavaidInfo]()
    let navaidPairs = [(11, 12), (13, 14), (15, 16), (17, 18)]
    for (nameIdx, typeIdx) in navaidPairs {
      if let name: String = try t[optional: nameIdx], !name.isEmpty {
        let navTypeStr: String = try t[optional: typeIdx] ?? ""
        let navType = LocationIdentifier.NavaidFacilityType(rawValue: navTypeStr)
        navaids.append(LocationIdentifier.NavaidInfo(name: name, facilityType: navType))
      }
    }

    let landingTypeStr: String = try t[optional: 9] ?? "",
      ILSTypeStr: String = try t[optional: 21] ?? "",
      ARTCCTypeStr: String = try t[optional: 27] ?? "",
      otherTypeStr: String = try t[optional: 30] ?? ""

    let record = LocationIdentifier(
      identifier: identifier,
      groupCode: .USA,
      FAARegion: try t[optional: 3],
      stateCode: try t[optional: 4],
      city: try t[optional: 5],
      controllingARTCC: try t[optional: 6],
      controllingARTCCComputerId: try t[optional: 7],
      landingFacilityName: try t[optional: 8],
      landingFacilityType: LocationIdentifier.LandingFacilityType(rawValue: landingTypeStr),
      landingFacilityFSS: try t[optional: 10],
      navaids: navaids,
      navaidFSS: try t[optional: 19],
      ILSRunwayEnd: try t[optional: 20],
      ilsFacilityType: LocationIdentifier.ILSFacilityType(rawValue: ILSTypeStr),
      ILSAirportIdentifier: try t[optional: 22],
      ILSAirportName: try t[optional: 23],
      ILSFSS: try t[optional: 24],
      FSSName: try t[optional: 25],
      ARTCCName: try t[optional: 26],
      artccFacilityType: LocationIdentifier.ARTCCFacilityType(rawValue: ARTCCTypeStr),
      isFlightWatchStation: try t[optional: 28],
      otherFacilityName: try t[optional: 29],
      otherFacilityType: LocationIdentifier.OtherFacilityType(rawValue: otherTypeStr),
      effectiveDateComponents: try t[optional: 31]
    )

    identifiers.append(record)
  }

  func finish(data: NASRData) async {
    await data.finishParsing(locationIdentifiers: identifiers)
  }
}
