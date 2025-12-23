import Foundation

enum FixRecordIdentifier: String {
  case basicInfo = "FIX1"
  case navaidMakeup = "FIX2"
  case ILSMakeup = "FIX3"
  case remark = "FIX4"
  case charting = "FIX5"
}

struct FixKey: Hashable {
  let id: String
  let stateName: String

  init(fix: Fix) {
    id = fix.id
    stateName = fix.stateName
  }

  init(values: FixedWidthTransformedRow) throws {
    id = try (values[1] as String).trimmingCharacters(in: .whitespaces)
    stateName = try (values[2] as String).trimmingCharacters(in: .whitespaces)
  }

  init(id: String, stateName: String) {
    self.id = id.trimmingCharacters(in: .whitespaces)
    self.stateName = stateName.trimmingCharacters(in: .whitespaces)
  }
}

actor FixedWidthFixParser: FixedWidthParser {
  typealias RecordIdentifier = FixRecordIdentifier

  static let type: RecordType = .reportingPoints
  static let layoutFormatOrder: [FixRecordIdentifier] = [
    .basicInfo, .navaidMakeup, .ILSMakeup, .remark, .charting
  ]

  var recordTypeRange: Range<UInt> { 0..<4 }
  var formats = [NASRTable]()
  var fixes = [FixKey: Fix]()

  // FIX1 - Base fix data
  private let basicTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type
    .string(),  //  1 fix ID
    .string(),  //  2 state name
    .string(nullable: .blank),  //  3 ICAO region code
    .DDMMSS(),  //  4 latitude
    .DDMMSS(),  //  5 longitude
    .recordEnum(Fix.Category.self, nullable: .blank),  //  6 category (MIL/FIX)
    .string(nullable: .blank),  //  7 navaid description
    .string(nullable: .blank),  //  8 radar description
    .string(nullable: .blank),  //  9 previous name
    .string(nullable: .blank),  // 10 charting info
    .boolean(),  // 11 published flag
    .recordEnum(Fix.Use.self, nullable: .blank),  // 12 fix use
    .string(nullable: .blank),  // 13 NAS ID
    .string(nullable: .blank),  // 14 high ARTCC code
    .string(nullable: .blank),  // 15 low ARTCC code
    .string(nullable: .blank),  // 16 country name
    .boolean(),  // 17 pitch flag
    .boolean(),  // 18 catch flag
    .boolean(),  // 19 SUA/ATCAA flag
    .null  // 20 blanks
  ])

  // FIX2 - Navaid makeup
  private let navaidMakeupTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 fix ID
    .string(),  // 2 state name
    .string(nullable: .blank),  // 3 ICAO region code
    .string(nullable: .blank),  // 4 navaid makeup description
    .null  // 5 blanks
  ])

  // FIX3 - ILS makeup
  private let ILSMakeupTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 fix ID
    .string(),  // 2 state name
    .string(nullable: .blank),  // 3 ICAO region code
    .string(nullable: .blank),  // 4 ILS makeup description
    .null  // 5 blanks
  ])

  // FIX4 - Remarks
  private let remarkTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 fix ID
    .string(),  // 2 state name
    .string(nullable: .blank),  // 3 ICAO region code
    .string(nullable: .blank),  // 4 field label
    .string(nullable: .blank)  // 5 remark text
  ])

  // FIX5 - Charting types
  private let chartingTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 fix ID
    .string(),  // 2 state name
    .string(nullable: .blank),  // 3 ICAO region code
    .string(nullable: .blank),  // 4 chart type
    .null  // 5 blanks
  ])

  func parseValues(_ values: [String], for identifier: FixRecordIdentifier) throws {
    switch identifier {
      case .basicInfo: try parseBasicRecord(values)
      case .navaidMakeup: try parseNavaidMakeup(values)
      case .ILSMakeup: try parseILSMakeup(values)
      case .remark: try parseRemark(values)
      case .charting: try parseCharting(values)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(fixes: Array(fixes.values))
  }

  private func parseBasicRecord(_ values: [String]) throws {
    let t = try basicTransformer.applyTo(values),
      lat: Float = try t[4],
      lon: Float = try t[5],
      position = Location(latitudeArcsec: lat, longitudeArcsec: lon)

    guard let category: Fix.Category = try t[optional: 6] else {
      throw ParserError.missingRequiredField(field: "category", recordType: "FIX1")
    }

    let fix = Fix(
      id: try t[1],
      stateName: try t[2],
      ICAORegion: try t[optional: 3],
      position: position,
      category: category,
      navaidDescription: try t[optional: 7],
      radarDescription: try t[optional: 8],
      previousName: try t[optional: 9],
      chartingInfo: try t[optional: 10],
      isPublished: try t[11],
      use: try t[optional: 12],
      NASId: try t[optional: 13],
      highARTCCCode: try t[optional: 14],
      lowARTCCCode: try t[optional: 15],
      country: try t[optional: 16],
      isPitchPoint: try t[optional: 17],
      isCatchPoint: try t[optional: 18],
      isAssociatedWithSUA: try t[optional: 19]
    )

    fixes[FixKey(fix: fix)] = fix
  }

  private func parseNavaidMakeup(_ values: [String]) throws {
    let t = try navaidMakeupTransformer.applyTo(values)

    guard let rawDescription: String = try t[optional: 4], !rawDescription.isEmpty else {
      return
    }

    try updateFix(t) { fix in
      if let makeup = parseNavaidMakeupDescription(rawDescription) {
        fix.navaidMakeups.append(makeup)
      }
    }
  }

  private func parseILSMakeup(_ values: [String]) throws {
    let t = try ILSMakeupTransformer.applyTo(values)

    guard let rawDescription: String = try t[optional: 4], !rawDescription.isEmpty else {
      return
    }

    try updateFix(t) { fix in
      if let makeup = parseILSMakeupDescription(rawDescription) {
        fix.ILSMakeups.append(makeup)
      }
    }
  }

  private func parseRemark(_ values: [String]) throws {
    let t = try remarkTransformer.applyTo(values)

    guard let fieldLabel: String = try t[optional: 4],
      let text: String = try t[optional: 5]
    else {
      return
    }

    try updateFix(t) { fix in
      let remark = FieldRemark(fieldLabel: fieldLabel, text: text)
      fix.remarks.append(remark)
    }
  }

  private func parseCharting(_ values: [String]) throws {
    let t = try chartingTransformer.applyTo(values)

    guard let chartType: String = try t[optional: 4] else {
      return
    }

    try updateFix(t) { fix in
      fix.chartTypes.insert(chartType)
    }
  }

  private func updateFix(_ values: FixedWidthTransformedRow, process: (inout Fix) throws -> Void)
    throws
  {
    let key = try FixKey(values: values)
    guard var fix = fixes[key] else {
      throw ParserError.unknownParentRecord(
        parentType: "Fix",
        parentID: key.id,
        childType: "continuation record"
      )
    }
    try process(&fix)
    fixes[key] = fix
  }
}

// MARK: - Makeup Parsing Helpers

private func parseNavaidMakeupDescription(_ description: String) -> Fix.NavaidMakeup? {
  // Format: LOCATOR*TYPE*RADIAL/DISTANCE (e.g., "ABC*V*090" or "ABC*D*270/12.5")
  let parts = description.components(separatedBy: "*")
  guard parts.count >= 2 else { return nil }

  let navaidId = parts[0]
  guard let navaidType = Navaid.FacilityType.for(parts[1]) else { return nil }

  var radialDeg: UInt?
  var distanceNM: Float?

  if parts.count >= 3 {
    let radialDistPart = parts[2]
    if radialDistPart.contains("/") {
      let subParts = radialDistPart.components(separatedBy: "/")
      radialDeg = UInt(subParts[0])
      if subParts.count > 1 {
        distanceNM = Float(subParts[1])
      }
    } else {
      radialDeg = UInt(radialDistPart)
    }
  }

  return Fix.NavaidMakeup(
    navaidId: navaidId,
    navaidType: navaidType,
    radialDeg: radialDeg,
    distanceNM: distanceNM,
    rawDescription: description
  )
}

private func parseILSMakeupDescription(_ description: String) -> Fix.ILSMakeup? {
  // Format: LOCATOR*TYPE*DIRECTION (e.g., "IBOS*LS*090")
  let parts = description.components(separatedBy: "*")
  guard parts.count >= 2 else { return nil }

  let ILSId = parts[0]
  guard let ILSType = ILSFacilityType.for(parts[1]) else { return nil }

  let direction = parts.count >= 3 ? parts[2] : nil

  return Fix.ILSMakeup(
    ILSId: ILSId,
    ILSType: ILSType,
    direction: direction,
    rawDescription: description
  )
}
