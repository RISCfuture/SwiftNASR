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

  init(values: [Any?]) {
    id = (values[1] as! String).trimmingCharacters(in: .whitespaces)
    stateName = (values[2] as! String).trimmingCharacters(in: .whitespaces)
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
    .generic({ try raw($0, toEnum: Fix.Category.self) }, nullable: .blank),  //  6 category (MIL/FIX)
    .string(nullable: .blank),  //  7 navaid description
    .string(nullable: .blank),  //  8 radar description
    .string(nullable: .blank),  //  9 previous name
    .string(nullable: .blank),  // 10 charting info
    .boolean(),  // 11 published flag
    .generic({ try raw($0, toEnum: Fix.Use.self) }, nullable: .blank),  // 12 fix use
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
    let transformedValues = try basicTransformer.applyTo(values)

    let position = Location(
      latitudeArcsec: transformedValues[4] as! Float,
      longitudeArcsec: transformedValues[5] as! Float
    )

    guard let category = transformedValues[6] as? Fix.Category else {
      throw ParserError.missingRequiredField(field: "category", recordType: "FIX1")
    }

    let fix = Fix(
      id: transformedValues[1] as! String,
      stateName: transformedValues[2] as! String,
      ICAORegion: transformedValues[3] as? String,
      position: position,
      category: category,
      navaidDescription: transformedValues[7] as? String,
      radarDescription: transformedValues[8] as? String,
      previousName: transformedValues[9] as? String,
      chartingInfo: transformedValues[10] as? String,
      isPublished: transformedValues[11] as! Bool,
      use: transformedValues[12] as? Fix.Use,
      NASId: transformedValues[13] as? String,
      highARTCCCode: transformedValues[14] as? String,
      lowARTCCCode: transformedValues[15] as? String,
      country: transformedValues[16] as? String,
      isPitchPoint: transformedValues[17] as? Bool,
      isCatchPoint: transformedValues[18] as? Bool,
      isAssociatedWithSUA: transformedValues[19] as? Bool
    )

    fixes[FixKey(fix: fix)] = fix
  }

  private func parseNavaidMakeup(_ values: [String]) throws {
    let transformedValues = try navaidMakeupTransformer.applyTo(values)

    guard let rawDescription = transformedValues[4] as? String, !rawDescription.isEmpty else {
      return
    }

    try updateFix(transformedValues) { fix in
      if let makeup = parseNavaidMakeupDescription(rawDescription) {
        fix.navaidMakeups.append(makeup)
      }
    }
  }

  private func parseILSMakeup(_ values: [String]) throws {
    let transformedValues = try ILSMakeupTransformer.applyTo(values)

    guard let rawDescription = transformedValues[4] as? String, !rawDescription.isEmpty else {
      return
    }

    try updateFix(transformedValues) { fix in
      if let makeup = parseILSMakeupDescription(rawDescription) {
        fix.ILSMakeups.append(makeup)
      }
    }
  }

  private func parseRemark(_ values: [String]) throws {
    let transformedValues = try remarkTransformer.applyTo(values)

    guard let fieldLabel = transformedValues[4] as? String,
      let text = transformedValues[5] as? String
    else {
      return
    }

    try updateFix(transformedValues) { fix in
      let remark = FieldRemark(fieldLabel: fieldLabel, text: text)
      fix.remarks.append(remark)
    }
  }

  private func parseCharting(_ values: [String]) throws {
    let transformedValues = try chartingTransformer.applyTo(values)

    guard let chartType = transformedValues[4] as? String else {
      return
    }

    try updateFix(transformedValues) { fix in
      fix.chartTypes.insert(chartType)
    }
  }

  private func updateFix(_ values: [Any?], process: (inout Fix) throws -> Void) throws {
    let key = FixKey(values: values)
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
