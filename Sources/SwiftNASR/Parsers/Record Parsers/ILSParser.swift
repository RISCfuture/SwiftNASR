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
    .recordEnum(ILS.SystemType.self, nullable: .blank),  //  3: system type [00019-00028]
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
    .recordEnum(ILS.Category.self, nullable: .blank),  // 14: category [00173-00181]
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
    .recordEnum(ILS.SystemType.self, nullable: .blank),  //  3: system type
    .recordEnum(OperationalStatus.self, nullable: .blank),  //  4: operational status [00029-00050]
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  5: status effective date [00051-00060]
    .DDMMSS(nullable: .blank),  //  6: latitude formatted [00061-00074]
    .null,  //  7: latitude all seconds [00075-00085] - skip, use formatted
    .DDMMSS(nullable: .blank),  //  8: longitude formatted [00086-00099]
    .null,  //  9: longitude all seconds [00100-00110] - skip, use formatted
    .recordEnum(ILS.PositionSource.self, nullable: .blank),  // 10: lat/lon source [00111-00112]
    .integer(nullable: .blank),  // 11: distance from approach end [00113-00119]
    .unsignedInteger(nullable: .blank),  // 12: distance from centerline [00120-00123]
    .string(nullable: .blank),  // 13: direction from centerline (L/R) [00124]
    .recordEnum(ILS.PositionSource.self, nullable: .blank),  // 14: distance source [00125-00126]
    .float(nullable: .blank),  // 15: site elevation [00127-00133]
    .float(nullable: .blank),  // 16: frequency [00134-00140]
    .recordEnum(ILS.BackCourseStatus.self, nullable: .blank),  // 17: back course status [00141-00155]
    .float(nullable: .blank),  // 18: course width [00156-00160]
    .float(nullable: .blank),  // 19: course width at threshold [00161-00167]
    .integer(nullable: .blank),  // 20: distance from stop end [00168-00174]
    .recordEnum(LateralDirection.self, nullable: .blank),  // 21: direction from stop end [00175]
    .recordEnum(ILS.LocalizerServiceCode.self, nullable: .blank),  // 22: service code [00176-00177]
    .null  // 23: blank [00178-00378]
  ])

  // ILS3 - Glide slope data
  private let glideSlopeTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (ILS3)
    .string(),  //  1: airport site number
    .string(),  //  2: runway end ID
    .recordEnum(ILS.SystemType.self, nullable: .blank),  //  3: system type
    .recordEnum(OperationalStatus.self, nullable: .blank),  //  4: operational status [00029-00050]
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  5: status effective date [00051-00060]
    .DDMMSS(nullable: .blank),  //  6: latitude formatted [00061-00074]
    .null,  //  7: latitude all seconds - skip
    .DDMMSS(nullable: .blank),  //  8: longitude formatted [00086-00099]
    .null,  //  9: longitude all seconds - skip
    .recordEnum(ILS.PositionSource.self, nullable: .blank),  // 10: lat/lon source [00111-00112]
    .integer(nullable: .blank),  // 11: distance from approach end [00113-00119]
    .unsignedInteger(nullable: .blank),  // 12: distance from centerline [00120-00123]
    .string(nullable: .blank),  // 13: direction from centerline (L/R) [00124]
    .recordEnum(ILS.PositionSource.self, nullable: .blank),  // 14: distance source [00125-00126]
    .float(nullable: .blank),  // 15: site elevation [00127-00133]
    .recordEnum(ILS.GlideSlope.GlidePathType.self, nullable: .blank),  // 16: glide slope type [00134-00148]
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
    .recordEnum(ILS.SystemType.self, nullable: .blank),  //  3: system type
    .recordEnum(OperationalStatus.self, nullable: .blank),  //  4: operational status [00029-00050]
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  5: status effective date [00051-00060]
    .DDMMSS(nullable: .blank),  //  6: latitude formatted [00061-00074]
    .null,  //  7: latitude all seconds - skip
    .DDMMSS(nullable: .blank),  //  8: longitude formatted [00086-00099]
    .null,  //  9: longitude all seconds - skip
    .recordEnum(ILS.PositionSource.self, nullable: .blank),  // 10: lat/lon source [00111-00112]
    .integer(nullable: .blank),  // 11: distance from approach end [00113-00119]
    .unsignedInteger(nullable: .blank),  // 12: distance from centerline [00120-00123]
    .string(nullable: .blank),  // 13: direction from centerline (L/R) [00124]
    .recordEnum(ILS.PositionSource.self, nullable: .blank),  // 14: distance source [00125-00126]
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
    .recordEnum(ILS.SystemType.self, nullable: .blank),  //  3: system type
    .recordEnum(ILS.MarkerBeacon.MarkerType.self, nullable: .blank),  //  4: marker type [00029-00030]
    .recordEnum(OperationalStatus.self, nullable: .blank),  //  5: operational status [00031-00052]
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  6: status effective date [00053-00062]
    .DDMMSS(nullable: .blank),  //  7: latitude formatted [00063-00076]
    .null,  //  8: latitude all seconds - skip
    .DDMMSS(nullable: .blank),  //  9: longitude formatted [00088-00101]
    .null,  // 10: longitude all seconds - skip
    .recordEnum(ILS.PositionSource.self, nullable: .blank),  // 11: lat/lon source [00113-00114]
    .integer(nullable: .blank),  // 12: distance from approach end [00115-00121]
    .unsignedInteger(nullable: .blank),  // 13: distance from centerline [00122-00125]
    .string(nullable: .blank),  // 14: direction from centerline (L/R) [00126]
    .recordEnum(ILS.PositionSource.self, nullable: .blank),  // 15: distance source [00127-00128]
    .float(nullable: .blank),  // 16: site elevation [00129-00135]
    .recordEnum(ILS.MarkerBeacon.MarkerFacilityType.self, nullable: .blank),  // 17: facility type [00136-00150]
    .string(nullable: .blank),  // 18: location ID [00151-00152]
    .string(nullable: .blank),  // 19: name [00153-00182]
    .unsignedInteger(nullable: .blank),  // 20: frequency [00183-00185]
    .string(nullable: .blank),  // 21: collocated navaid [00186-00210]
    .recordEnum(OperationalStatus.self, nullable: .blank),  // 22: low power NDB status [00211-00232]
    .string(nullable: .blank),  // 23: service [00233-00262]
    .null  // 24: blank [00263-00378]
  ])

  // ILS6 - Remark
  private let remarkTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (ILS6)
    .string(),  //  1: airport site number
    .string(),  //  2: runway end ID
    .recordEnum(ILS.SystemType.self, nullable: .blank),  //  3: system type
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
    let t = try baseTransformer.applyTo(values),
      airportSiteNumber = try (t[1] as String).trimmingCharacters(in: .whitespaces),
      runwayEndId = try (t[2] as String).trimmingCharacters(in: .whitespaces)
    guard let systemType: ILS.SystemType = try t[optional: 3] else {
      throw ParserError.missingRequiredField(field: "systemType", recordType: "ILS1")
    }
    let ILSId: String? = try t[optional: 4],
      effectiveDate: DateComponents? = try t[optional: 5],
      airportName: String? = try t[optional: 6],
      city: String? = try t[optional: 7],
      stateCode: String? = try t[optional: 8],
      stateName: String? = try t[optional: 9],
      regionCode: String? = try t[optional: 10],
      airportId: String? = try t[optional: 11],
      runwayLength: UInt? = try t[optional: 12],
      runwayWidth: UInt? = try t[optional: 13],
      category: ILS.Category? = try t[optional: 14],
      owner: String? = try t[optional: 15],
      operatorName: String? = try t[optional: 16],
      rawApproachBearing: Float? = try t[optional: 17],
      magVarString: String? = try t[optional: 18]

    let magneticVariation: Int? = {
      guard let magVarString, !magVarString.isEmpty else { return nil }
      let isWest = magVarString.hasSuffix("W"),
        isEast = magVarString.hasSuffix("E")
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
  /// - Throws: `ParserError.invalidValue` for unknown direction values.
  private func signedCenterlineDistance(distance: UInt?, direction: String?) throws -> Int? {
    guard let distance else { return nil }
    guard let direction, !direction.isEmpty else { return Int(distance) }
    switch direction {
      case "L": return -Int(distance)
      case "R": return Int(distance)
      default: throw ParserError.invalidValue("centerline direction: \(direction)")
    }
  }

  private func parseLocalizerRecord(_ values: [String]) throws {
    let t = try localizerTransformer.applyTo(values),
      airportSiteNumber = try (t[1] as String).trimmingCharacters(in: .whitespaces),
      runwayEndId = try (t[2] as String).trimmingCharacters(in: .whitespaces)
    guard let systemType: ILS.SystemType = try t[optional: 3] else {
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

    let lat: Float? = try t[optional: 6],
      lon: Float? = try t[optional: 8],
      elev: Float? = try t[optional: 15],
      LOCPosition = try makeLocation(
        latitude: lat,
        longitude: lon,
        elevation: elev,
        context: "ILS localizer \(airportSiteNumber)/\(runwayEndId)"
      )

    let clDist: UInt? = try t[optional: 12],
      clDir: String? = try t[optional: 13],
      freq: Float? = try t[optional: 16],
      localizer = ILS.Localizer(
        status: try t[optional: 4],
        statusDateComponents: try t[optional: 5],
        position: LOCPosition,
        positionSource: try t[optional: 10],
        distanceFromApproachEndFt: try t[optional: 11],
        distanceFromCenterlineFt: try signedCenterlineDistance(distance: clDist, direction: clDir),
        distanceSource: try t[optional: 14],
        frequencyKHz: freq.map { UInt($0 * 1000) },
        backCourseStatus: try t[optional: 17],
        courseWidthDeg: try t[optional: 18],
        courseWidthAtThresholdDeg: try t[optional: 19],
        distanceFromStopEndFt: try t[optional: 20],
        directionFromStopEnd: try t[optional: 21],
        serviceCode: try t[optional: 22]
      )

    ILSFacilities[key]?.localizer = localizer
  }

  private func parseGlideSlopeRecord(_ values: [String]) throws {
    let t = try glideSlopeTransformer.applyTo(values),
      airportSiteNumber = try (t[1] as String).trimmingCharacters(in: .whitespaces),
      runwayEndId = try (t[2] as String).trimmingCharacters(in: .whitespaces)
    guard let systemType: ILS.SystemType = try t[optional: 3] else {
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

    let lat: Float? = try t[optional: 6],
      lon: Float? = try t[optional: 8],
      elev: Float? = try t[optional: 15],
      gsPosition = try makeLocation(
        latitude: lat,
        longitude: lon,
        elevation: elev,
        context: "ILS glide slope \(airportSiteNumber)/\(runwayEndId)"
      )

    let clDist: UInt? = try t[optional: 12],
      clDir: String? = try t[optional: 13],
      freq: Float? = try t[optional: 18],
      glideSlope = ILS.GlideSlope(
        status: try t[optional: 4],
        statusDateComponents: try t[optional: 5],
        position: gsPosition,
        positionSource: try t[optional: 10],
        distanceFromApproachEndFt: try t[optional: 11],
        distanceFromCenterlineFt: try signedCenterlineDistance(distance: clDist, direction: clDir),
        distanceSource: try t[optional: 14],
        glideSlopeType: try t[optional: 16],
        angleDeg: try t[optional: 17],
        frequencyKHz: freq.map { UInt($0 * 1000) },
        adjacentRunwayElevationFtMSL: try t[optional: 19]
      )

    ILSFacilities[key]?.glideSlope = glideSlope
  }

  private func parseDMERecord(_ values: [String]) throws {
    let t = try dmeTransformer.applyTo(values),
      airportSiteNumber = try (t[1] as String).trimmingCharacters(in: .whitespaces),
      runwayEndId = try (t[2] as String).trimmingCharacters(in: .whitespaces)
    guard let systemType: ILS.SystemType = try t[optional: 3] else {
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

    let lat: Float? = try t[optional: 6],
      lon: Float? = try t[optional: 8],
      elev: Float? = try t[optional: 15],
      DMEPosition = try makeLocation(
        latitude: lat,
        longitude: lon,
        elevation: elev,
        context: "ILS DME \(airportSiteNumber)/\(runwayEndId)"
      )

    let clDist: UInt? = try t[optional: 12],
      clDir: String? = try t[optional: 13],
      DME = ILS.DME(
        status: try t[optional: 4],
        statusDateComponents: try t[optional: 5],
        position: DMEPosition,
        positionSource: try t[optional: 10],
        distanceFromApproachEndFt: try t[optional: 11],
        distanceFromCenterlineFt: try signedCenterlineDistance(distance: clDist, direction: clDir),
        distanceSource: try t[optional: 14],
        channel: try t[optional: 16],
        distanceFromStopEndFt: try t[optional: 17]
      )

    ILSFacilities[key]?.dme = DME
  }

  private func parseMarkerRecord(_ values: [String]) throws {
    let t = try markerTransformer.applyTo(values),
      airportSiteNumber = try (t[1] as String).trimmingCharacters(in: .whitespaces),
      runwayEndId = try (t[2] as String).trimmingCharacters(in: .whitespaces)
    guard let systemType: ILS.SystemType = try t[optional: 3] else {
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

    guard let markerType: ILS.MarkerBeacon.MarkerType = try t[optional: 4] else {
      throw ParserError.missingRequiredField(field: "markerType", recordType: "ILS5")
    }

    let lat: Float? = try t[optional: 7],
      lon: Float? = try t[optional: 9],
      elev: Float? = try t[optional: 16],
      mkrPosition = try makeLocation(
        latitude: lat,
        longitude: lon,
        elevation: elev,
        context: "ILS marker beacon \(airportSiteNumber)/\(runwayEndId)"
      )

    let clDist: UInt? = try t[optional: 13],
      clDir: String? = try t[optional: 14],
      marker = ILS.MarkerBeacon(
        markerType: markerType,
        status: try t[optional: 5],
        statusDateComponents: try t[optional: 6],
        position: mkrPosition,
        positionSource: try t[optional: 11],
        distanceFromApproachEndFt: try t[optional: 12],
        distanceFromCenterlineFt: try signedCenterlineDistance(distance: clDist, direction: clDir),
        distanceSource: try t[optional: 15],
        facilityType: try t[optional: 17],
        locationId: try t[optional: 18],
        name: try t[optional: 19],
        frequencyKHz: try t[optional: 20],
        collocatedNavaid: try t[optional: 21],
        lowPoweredNDBStatus: try t[optional: 22],
        service: try t[optional: 23]
      )

    ILSFacilities[key]?.markers.append(marker)
  }

  private func parseRemarkRecord(_ values: [String]) throws {
    let t = try remarkTransformer.applyTo(values),
      airportSiteNumber = try (t[1] as String).trimmingCharacters(in: .whitespaces),
      runwayEndId = try (t[2] as String).trimmingCharacters(in: .whitespaces)
    guard let systemType: ILS.SystemType = try t[optional: 3] else {
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

    if let remark: String = try t[optional: 4], !remark.isEmpty {
      ILSFacilities[key]?.remarks.append(remark)
    }
  }
}
