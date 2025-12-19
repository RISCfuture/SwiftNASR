import Foundation

enum ILSRecordIdentifier: String {
  case base = "ILS1"
  case localizer = "ILS2"
  case glideSlope = "ILS3"
  case dme = "ILS4"
  case marker = "ILS5"
  case remark = "ILS6"
}

struct ILSKey: Hashable {
  let airportSiteNumber: String
  let runwayEndId: String
  let systemType: ILS.SystemType

  init(ils: ILS) {
    airportSiteNumber = ils.airportSiteNumber
    runwayEndId = ils.runwayEndId
    systemType = ils.systemType
  }

  init(airportSiteNumber: String, runwayEndId: String, systemType: ILS.SystemType) {
    self.airportSiteNumber = airportSiteNumber
    self.runwayEndId = runwayEndId
    self.systemType = systemType
  }
}

actor FixedWidthILSParser: FixedWidthParser {
  typealias RecordIdentifier = ILSRecordIdentifier

  static let type: RecordType = .ILSes
  static let layoutFormatOrder: [ILSRecordIdentifier] = [
    .base, .localizer, .glideSlope, .dme, .marker, .remark
  ]

  var recordTypeRange: Range<UInt> { 0..<4 }
  var formats = [NASRTable]()
  var ILSFacilities = [ILSKey: ILS]()

  // ILS1 - Base data
  // Layout positions based on ils_rf.txt (1-indexed positions converted to 0-indexed)
  private let baseTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (ILS1)
    .string(),  //  1: airport site number [00005-00015]
    .string(),  //  2: runway end ID [00016-00018]
    .generic({ try raw($0, toEnum: ILS.SystemType.self) }, nullable: .blank),  //  3: system type [00019-00028]
    .string(nullable: .blank),  //  4: ILS ID [00029-00034]
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  5: effective date [00035-00044]
    .string(nullable: .blank),  //  6: airport name [00045-00094]
    .string(nullable: .blank),  //  7: city [00095-00134]
    .string(nullable: .blank),  //  8: state code [00135-00136]
    .string(nullable: .blank),  //  9: state name [00137-00156]
    .string(nullable: .blank),  // 10: region code [00157-00159]
    .string(nullable: .blank),  // 11: airport ID [00160-00163]
    .unsignedInteger(nullable: .blank),  // 12: runway length [00164-00168]
    .unsignedInteger(nullable: .blank),  // 13: runway width [00169-00172]
    .generic({ try raw($0, toEnum: ILS.Category.self) }, nullable: .blank),  // 14: category [00173-00181]
    .string(nullable: .blank),  // 15: owner [00182-00231]
    .string(nullable: .blank),  // 16: operator [00232-00281]
    .float(nullable: .blank),  // 17: approach bearing [00282-00287]
    .string(nullable: .blank),  // 18: magnetic variation [00288-00290]
    .null  // 19: blank [00291-00378]
  ])

  // ILS2 - Localizer data
  private let localizerTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (ILS2)
    .string(),  //  1: airport site number
    .string(),  //  2: runway end ID
    .generic({ try raw($0, toEnum: ILS.SystemType.self) }, nullable: .blank),  //  3: system type
    .generic({ try raw($0, toEnum: OperationalStatus.self) }, nullable: .blank),  //  4: operational status [00029-00050]
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  5: status effective date [00051-00060]
    .DDMMSS(nullable: .blank),  //  6: latitude formatted [00061-00074]
    .null,  //  7: latitude all seconds [00075-00085] - skip, use formatted
    .DDMMSS(nullable: .blank),  //  8: longitude formatted [00086-00099]
    .null,  //  9: longitude all seconds [00100-00110] - skip, use formatted
    .generic({ try raw($0, toEnum: ILS.PositionSource.self) }, nullable: .blank),  // 10: lat/lon source [00111-00112]
    .integer(nullable: .blank),  // 11: distance from approach end [00113-00119]
    .unsignedInteger(nullable: .blank),  // 12: distance from centerline [00120-00123]
    .string(nullable: .blank),  // 13: direction from centerline (L/R) [00124]
    .generic({ try raw($0, toEnum: ILS.PositionSource.self) }, nullable: .blank),  // 14: distance source [00125-00126]
    .float(nullable: .blank),  // 15: site elevation [00127-00133]
    .float(nullable: .blank),  // 16: frequency [00134-00140]
    .generic({ try raw($0, toEnum: ILS.BackCourseStatus.self) }, nullable: .blank),  // 17: back course status [00141-00155]
    .float(nullable: .blank),  // 18: course width [00156-00160]
    .float(nullable: .blank),  // 19: course width at threshold [00161-00167]
    .integer(nullable: .blank),  // 20: distance from stop end [00168-00174]
    .generic({ try raw($0, toEnum: LateralDirection.self) }, nullable: .blank),  // 21: direction from stop end [00175]
    .generic({ try raw($0, toEnum: ILS.LocalizerServiceCode.self) }, nullable: .blank),  // 22: service code [00176-00177]
    .null  // 23: blank [00178-00378]
  ])

  // ILS3 - Glide slope data
  private let glideSlopeTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (ILS3)
    .string(),  //  1: airport site number
    .string(),  //  2: runway end ID
    .generic({ try raw($0, toEnum: ILS.SystemType.self) }, nullable: .blank),  //  3: system type
    .generic({ try raw($0, toEnum: OperationalStatus.self) }, nullable: .blank),  //  4: operational status [00029-00050]
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  5: status effective date [00051-00060]
    .DDMMSS(nullable: .blank),  //  6: latitude formatted [00061-00074]
    .null,  //  7: latitude all seconds - skip
    .DDMMSS(nullable: .blank),  //  8: longitude formatted [00086-00099]
    .null,  //  9: longitude all seconds - skip
    .generic({ try raw($0, toEnum: ILS.PositionSource.self) }, nullable: .blank),  // 10: lat/lon source [00111-00112]
    .integer(nullable: .blank),  // 11: distance from approach end [00113-00119]
    .unsignedInteger(nullable: .blank),  // 12: distance from centerline [00120-00123]
    .string(nullable: .blank),  // 13: direction from centerline (L/R) [00124]
    .generic({ try raw($0, toEnum: ILS.PositionSource.self) }, nullable: .blank),  // 14: distance source [00125-00126]
    .float(nullable: .blank),  // 15: site elevation [00127-00133]
    .generic({ try raw($0, toEnum: ILS.GlideSlope.GlidePathType.self) }, nullable: .blank),  // 16: glide slope type [00134-00148]
    .float(nullable: .blank),  // 17: glide slope angle [00149-00153]
    .float(nullable: .blank),  // 18: frequency [00154-00160]
    .float(nullable: .blank),  // 19: runway elevation adjacent [00161-00168]
    .null  // 20: blank [00169-00378]
  ])

  // ILS4 - DME data
  private let dmeTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (ILS4)
    .string(),  //  1: airport site number
    .string(),  //  2: runway end ID
    .generic({ try raw($0, toEnum: ILS.SystemType.self) }, nullable: .blank),  //  3: system type
    .generic({ try raw($0, toEnum: OperationalStatus.self) }, nullable: .blank),  //  4: operational status [00029-00050]
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  5: status effective date [00051-00060]
    .DDMMSS(nullable: .blank),  //  6: latitude formatted [00061-00074]
    .null,  //  7: latitude all seconds - skip
    .DDMMSS(nullable: .blank),  //  8: longitude formatted [00086-00099]
    .null,  //  9: longitude all seconds - skip
    .generic({ try raw($0, toEnum: ILS.PositionSource.self) }, nullable: .blank),  // 10: lat/lon source [00111-00112]
    .integer(nullable: .blank),  // 11: distance from approach end [00113-00119]
    .unsignedInteger(nullable: .blank),  // 12: distance from centerline [00120-00123]
    .string(nullable: .blank),  // 13: direction from centerline (L/R) [00124]
    .generic({ try raw($0, toEnum: ILS.PositionSource.self) }, nullable: .blank),  // 14: distance source [00125-00126]
    .float(nullable: .blank),  // 15: site elevation [00127-00133]
    .string(nullable: .blank),  // 16: channel [00134-00137]
    .integer(nullable: .blank),  // 17: distance from stop end [00138-00144]
    .null  // 18: blank [00145-00378]
  ])

  // ILS5 - Marker beacon data
  private let markerTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (ILS5)
    .string(),  //  1: airport site number
    .string(),  //  2: runway end ID
    .generic({ try raw($0, toEnum: ILS.SystemType.self) }, nullable: .blank),  //  3: system type
    .generic({ try raw($0, toEnum: ILS.MarkerBeacon.MarkerType.self) }, nullable: .blank),  //  4: marker type [00029-00030]
    .generic({ try raw($0, toEnum: OperationalStatus.self) }, nullable: .blank),  //  5: operational status [00031-00052]
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  6: status effective date [00053-00062]
    .DDMMSS(nullable: .blank),  //  7: latitude formatted [00063-00076]
    .null,  //  8: latitude all seconds - skip
    .DDMMSS(nullable: .blank),  //  9: longitude formatted [00088-00101]
    .null,  // 10: longitude all seconds - skip
    .generic({ try raw($0, toEnum: ILS.PositionSource.self) }, nullable: .blank),  // 11: lat/lon source [00113-00114]
    .integer(nullable: .blank),  // 12: distance from approach end [00115-00121]
    .unsignedInteger(nullable: .blank),  // 13: distance from centerline [00122-00125]
    .string(nullable: .blank),  // 14: direction from centerline (L/R) [00126]
    .generic({ try raw($0, toEnum: ILS.PositionSource.self) }, nullable: .blank),  // 15: distance source [00127-00128]
    .float(nullable: .blank),  // 16: site elevation [00129-00135]
    .generic({ try raw($0, toEnum: ILS.MarkerBeacon.MarkerFacilityType.self) }, nullable: .blank),  // 17: facility type [00136-00150]
    .string(nullable: .blank),  // 18: location ID [00151-00152]
    .string(nullable: .blank),  // 19: name [00153-00182]
    .unsignedInteger(nullable: .blank),  // 20: frequency [00183-00185]
    .string(nullable: .blank),  // 21: collocated navaid [00186-00210]
    .generic({ try raw($0, toEnum: OperationalStatus.self) }, nullable: .blank),  // 22: low power NDB status [00211-00232]
    .string(nullable: .blank),  // 23: service [00233-00262]
    .null  // 24: blank [00263-00378]
  ])

  // ILS6 - Remark
  private let remarkTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (ILS6)
    .string(),  //  1: airport site number
    .string(),  //  2: runway end ID
    .generic({ try raw($0, toEnum: ILS.SystemType.self) }, nullable: .blank),  //  3: system type
    .string(nullable: .blank)  //  4: remark text [00029-00378]
  ])

  func parseValues(_ values: [String], for identifier: ILSRecordIdentifier) throws {
    switch identifier {
      case .base: try parseBaseRecord(values)
      case .localizer: try parseLocalizerRecord(values)
      case .glideSlope: try parseGlideSlopeRecord(values)
      case .dme: try parseDMERecord(values)
      case .marker: try parseMarkerRecord(values)
      case .remark: try parseRemarkRecord(values)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(ILSFacilities: Array(ILSFacilities.values))
  }

  /// Creates a Location from optional lat/lon/elev, throwing if only one of lat/lon is present.
  private func makeLocation(
    latitude: Float?,
    longitude: Float?,
    elevation: Float?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        return Location(latitudeArcsec: lat, longitudeArcsec: lon, elevationFtMSL: elevation)
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

  private func parseBaseRecord(_ values: [String]) throws {
    let transformedValues = try baseTransformer.applyTo(values)

    let airportSiteNumber = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    let runwayEndId = (transformedValues[2] as! String).trimmingCharacters(in: .whitespaces)
    guard let systemType = transformedValues[3] as? ILS.SystemType else {
      throw ParserError.missingRequiredField(field: "systemType", recordType: "ILS1")
    }
    let ILSId = transformedValues[4] as? String
    let effectiveDate = transformedValues[5] as? DateComponents
    let airportName = transformedValues[6] as? String
    let city = transformedValues[7] as? String
    let stateCode = transformedValues[8] as? String
    let stateName = transformedValues[9] as? String
    let regionCode = transformedValues[10] as? String
    let airportId = transformedValues[11] as? String
    let runwayLength = transformedValues[12] as? UInt
    let runwayWidth = transformedValues[13] as? UInt
    let category = transformedValues[14] as? ILS.Category
    let owner = transformedValues[15] as? String
    let operatorName = transformedValues[16] as? String
    let rawApproachBearing = transformedValues[17] as? Float
    let magneticVariation: Int? = {
      guard let magVarString = transformedValues[18] as? String, !magVarString.isEmpty else {
        return nil
      }
      let isWest = magVarString.hasSuffix("W")
      let isEast = magVarString.hasSuffix("E")
      guard isWest || isEast else { return nil }
      let numberPart = magVarString.dropLast()
      guard let value = Int(numberPart.trimmingCharacters(in: .whitespaces)) else { return nil }
      return isWest ? -value : value
    }()

    // Convert approach bearing to Bearing<Float>
    let approachBearing = rawApproachBearing.map { value in
      Bearing(value, reference: .magnetic, magneticVariationDeg: magneticVariation ?? 0)
    }

    let key = ILSKey(
      airportSiteNumber: airportSiteNumber,
      runwayEndId: runwayEndId,
      systemType: systemType
    )

    let ils = ILS(
      airportSiteNumber: airportSiteNumber,
      runwayEndId: runwayEndId,
      systemType: systemType,
      ILSId: ILSId ?? "",
      airportId: airportId ?? "",
      airportName: airportName ?? "",
      city: city ?? "",
      stateCode: stateCode,
      stateName: stateName,
      regionCode: regionCode,
      runwayLengthFt: runwayLength,
      runwayWidthFt: runwayWidth,
      category: category,
      owner: owner,
      operator: operatorName,
      approachBearing: approachBearing,
      magneticVariationDeg: magneticVariation,
      effectiveDateComponents: effectiveDate
    )

    ILSFacilities[key] = ils
  }

  /// Combines unsigned distance and L/R direction into signed distance (negative = left).
  private func signedCenterlineDistance(distance: UInt?, direction: String?) -> Int? {
    guard let distance else { return nil }
    let sign = direction == "L" ? -1 : 1
    return sign * Int(distance)
  }

  private func parseLocalizerRecord(_ values: [String]) throws {
    let transformedValues = try localizerTransformer.applyTo(values)

    let airportSiteNumber = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    let runwayEndId = (transformedValues[2] as! String).trimmingCharacters(in: .whitespaces)
    guard let systemType = transformedValues[3] as? ILS.SystemType else {
      throw ParserError.missingRequiredField(field: "systemType", recordType: "ILS2")
    }

    let key = ILSKey(
      airportSiteNumber: airportSiteNumber,
      runwayEndId: runwayEndId,
      systemType: systemType
    )

    guard ILSFacilities[key] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "ILS",
        parentID: "\(airportSiteNumber)/\(runwayEndId)/\(systemType)",
        childType: "localizer"
      )
    }

    let LOCPosition = try makeLocation(
      latitude: transformedValues[6] as? Float,
      longitude: transformedValues[8] as? Float,
      elevation: transformedValues[15] as? Float,
      context: "ILS localizer \(airportSiteNumber)/\(runwayEndId)"
    )

    let localizer = ILS.Localizer(
      status: transformedValues[4] as? OperationalStatus,
      statusDateComponents: transformedValues[5] as? DateComponents,
      position: LOCPosition,
      positionSource: transformedValues[10] as? ILS.PositionSource,
      distanceFromApproachEndFt: transformedValues[11] as? Int,
      distanceFromCenterlineFt: signedCenterlineDistance(
        distance: transformedValues[12] as? UInt,
        direction: transformedValues[13] as? String
      ),
      distanceSource: transformedValues[14] as? ILS.PositionSource,
      frequencyKHz: (transformedValues[16] as? Float).map { UInt($0 * 1000) },
      backCourseStatus: transformedValues[17] as? ILS.BackCourseStatus,
      courseWidthDeg: transformedValues[18] as? Float,
      courseWidthAtThresholdDeg: transformedValues[19] as? Float,
      distanceFromStopEndFt: transformedValues[20] as? Int,
      directionFromStopEnd: transformedValues[21] as? LateralDirection,
      serviceCode: transformedValues[22] as? ILS.LocalizerServiceCode
    )

    ILSFacilities[key]?.localizer = localizer
  }

  private func parseGlideSlopeRecord(_ values: [String]) throws {
    let transformedValues = try glideSlopeTransformer.applyTo(values)

    let airportSiteNumber = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    let runwayEndId = (transformedValues[2] as! String).trimmingCharacters(in: .whitespaces)
    guard let systemType = transformedValues[3] as? ILS.SystemType else {
      throw ParserError.missingRequiredField(field: "systemType", recordType: "ILS3")
    }

    let key = ILSKey(
      airportSiteNumber: airportSiteNumber,
      runwayEndId: runwayEndId,
      systemType: systemType
    )

    guard ILSFacilities[key] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "ILS",
        parentID: "\(airportSiteNumber)/\(runwayEndId)/\(systemType)",
        childType: "glide slope"
      )
    }

    let gsPosition = try makeLocation(
      latitude: transformedValues[6] as? Float,
      longitude: transformedValues[8] as? Float,
      elevation: transformedValues[15] as? Float,
      context: "ILS glide slope \(airportSiteNumber)/\(runwayEndId)"
    )

    let glideSlope = ILS.GlideSlope(
      status: transformedValues[4] as? OperationalStatus,
      statusDateComponents: transformedValues[5] as? DateComponents,
      position: gsPosition,
      positionSource: transformedValues[10] as? ILS.PositionSource,
      distanceFromApproachEndFt: transformedValues[11] as? Int,
      distanceFromCenterlineFt: signedCenterlineDistance(
        distance: transformedValues[12] as? UInt,
        direction: transformedValues[13] as? String
      ),
      distanceSource: transformedValues[14] as? ILS.PositionSource,
      glideSlopeType: transformedValues[16] as? ILS.GlideSlope.GlidePathType,
      angleDeg: transformedValues[17] as? Float,
      frequencyKHz: (transformedValues[18] as? Float).map { UInt($0 * 1000) },
      adjacentRunwayElevationFtMSL: transformedValues[19] as? Float
    )

    ILSFacilities[key]?.glideSlope = glideSlope
  }

  private func parseDMERecord(_ values: [String]) throws {
    let transformedValues = try dmeTransformer.applyTo(values)

    let airportSiteNumber = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    let runwayEndId = (transformedValues[2] as! String).trimmingCharacters(in: .whitespaces)
    guard let systemType = transformedValues[3] as? ILS.SystemType else {
      throw ParserError.missingRequiredField(field: "systemType", recordType: "ILS4")
    }

    let key = ILSKey(
      airportSiteNumber: airportSiteNumber,
      runwayEndId: runwayEndId,
      systemType: systemType
    )

    guard ILSFacilities[key] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "ILS",
        parentID: "\(airportSiteNumber)/\(runwayEndId)/\(systemType)",
        childType: "DME"
      )
    }

    let DMEPosition = try makeLocation(
      latitude: transformedValues[6] as? Float,
      longitude: transformedValues[8] as? Float,
      elevation: transformedValues[15] as? Float,
      context: "ILS DME \(airportSiteNumber)/\(runwayEndId)"
    )

    let DME = ILS.DME(
      status: transformedValues[4] as? OperationalStatus,
      statusDateComponents: transformedValues[5] as? DateComponents,
      position: DMEPosition,
      positionSource: transformedValues[10] as? ILS.PositionSource,
      distanceFromApproachEndFt: transformedValues[11] as? Int,
      distanceFromCenterlineFt: signedCenterlineDistance(
        distance: transformedValues[12] as? UInt,
        direction: transformedValues[13] as? String
      ),
      distanceSource: transformedValues[14] as? ILS.PositionSource,
      channel: transformedValues[16] as? String,
      distanceFromStopEndFt: transformedValues[17] as? Int
    )

    ILSFacilities[key]?.dme = DME
  }

  private func parseMarkerRecord(_ values: [String]) throws {
    let transformedValues = try markerTransformer.applyTo(values)

    let airportSiteNumber = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    let runwayEndId = (transformedValues[2] as! String).trimmingCharacters(in: .whitespaces)
    guard let systemType = transformedValues[3] as? ILS.SystemType else {
      throw ParserError.missingRequiredField(field: "systemType", recordType: "ILS5")
    }

    let key = ILSKey(
      airportSiteNumber: airportSiteNumber,
      runwayEndId: runwayEndId,
      systemType: systemType
    )

    guard ILSFacilities[key] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "ILS",
        parentID: "\(airportSiteNumber)/\(runwayEndId)/\(systemType)",
        childType: "marker beacon"
      )
    }

    guard let markerType = transformedValues[4] as? ILS.MarkerBeacon.MarkerType else {
      throw ParserError.missingRequiredField(field: "markerType", recordType: "ILS5")
    }

    let mkrPosition = try makeLocation(
      latitude: transformedValues[7] as? Float,
      longitude: transformedValues[9] as? Float,
      elevation: transformedValues[16] as? Float,
      context: "ILS marker beacon \(airportSiteNumber)/\(runwayEndId)"
    )

    let marker = ILS.MarkerBeacon(
      markerType: markerType,
      status: transformedValues[5] as? OperationalStatus,
      statusDateComponents: transformedValues[6] as? DateComponents,
      position: mkrPosition,
      positionSource: transformedValues[11] as? ILS.PositionSource,
      distanceFromApproachEndFt: transformedValues[12] as? Int,
      distanceFromCenterlineFt: signedCenterlineDistance(
        distance: transformedValues[13] as? UInt,
        direction: transformedValues[14] as? String
      ),
      distanceSource: transformedValues[15] as? ILS.PositionSource,
      facilityType: transformedValues[17] as? ILS.MarkerBeacon.MarkerFacilityType,
      locationId: transformedValues[18] as? String,
      name: transformedValues[19] as? String,
      frequencyKHz: transformedValues[20] as? UInt,
      collocatedNavaid: transformedValues[21] as? String,
      lowPoweredNDBStatus: transformedValues[22] as? OperationalStatus,
      service: transformedValues[23] as? String
    )

    ILSFacilities[key]?.markers.append(marker)
  }

  private func parseRemarkRecord(_ values: [String]) throws {
    let transformedValues = try remarkTransformer.applyTo(values)

    let airportSiteNumber = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    let runwayEndId = (transformedValues[2] as! String).trimmingCharacters(in: .whitespaces)
    guard let systemType = transformedValues[3] as? ILS.SystemType else {
      throw ParserError.missingRequiredField(field: "systemType", recordType: "ILS6")
    }

    let key = ILSKey(
      airportSiteNumber: airportSiteNumber,
      runwayEndId: runwayEndId,
      systemType: systemType
    )

    guard ILSFacilities[key] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "ILS",
        parentID: "\(airportSiteNumber)/\(runwayEndId)/\(systemType)",
        childType: "remark"
      )
    }

    if let remark = transformedValues[4] as? String, !remark.isEmpty {
      ILSFacilities[key]?.remarks.append(remark)
    }
  }
}
