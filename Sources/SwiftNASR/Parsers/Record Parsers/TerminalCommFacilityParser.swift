import Foundation

enum TWRRecordIdentifier: String {
  case base = "TWR1"
  case hours = "TWR2"
  case frequencies = "TWR3"
  case services = "TWR4"
  case radar = "TWR5"
  case remark = "TWR6"
  case satellite = "TWR7"
  case airspace = "TWR8"
  case atis = "TWR9"
}

class FixedWidthTerminalCommFacilityParser: FixedWidthParser {
  typealias RecordIdentifier = TWRRecordIdentifier

  static let type: RecordType = .terminalCommFacilities
  static let layoutFormatOrder: [TWRRecordIdentifier] = [
    .base, .hours, .frequencies, .services, .radar, .remark, .satellite, .airspace, .atis
  ]

  var recordTypeRange: Range<UInt> { 0..<4 }
  var formats = [NASRTable]()
  var facilities = [String: TerminalCommFacility]()

  // TWR1 - Base data (record length 1608)
  private let baseTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (TWR1)
    .string(),  //  1: facility ID [00005-00008]
    .dateComponents(format: .monthDayYearSlash, nullable: .blank),  //  2: effective date [00009-00018]
    .string(nullable: .blank),  //  3: airport site number [00019-00029]
    .string(nullable: .blank),  //  4: FAA region code [00030-00032]
    .string(nullable: .blank),  //  5: state name [00033-00062]
    .string(nullable: .blank),  //  6: state code [00063-00064]
    .string(nullable: .blank),  //  7: city [00065-00104]
    .string(nullable: .blank),  //  8: airport name [00105-00154]
    .DDMMSS(nullable: .blank),  //  9: airport latitude formatted [00155-00168]
    .null,  // 10: airport latitude seconds [00169-00179]
    .DDMMSS(nullable: .blank),  // 11: airport longitude formatted [00180-00193]
    .null,  // 12: airport longitude seconds [00194-00204]
    .string(nullable: .blank),  // 13: tie-in FSS ID [00205-00208]
    .string(nullable: .blank),  // 14: tie-in FSS name [00209-00238]
    .generic({ try raw($0, toEnum: TerminalCommFacility.FacilityType.self) }, nullable: .blank),  // 15: facility type [00239-00250]
    .string(nullable: .blank),  // 16: hours of operation [00251-00252]
    .generic(
      { try raw($0, toEnum: TerminalCommFacility.OperationRegularity.self) },
      nullable: .blank
    ),  // 17: operation regularity [00253-00255]
    .string(nullable: .blank),  // 18: master airport ID [00256-00259]
    .string(nullable: .blank),  // 19: master airport name [00260-00309]
    .generic(
      { try raw($0, toEnum: TerminalCommFacility.DirectionFindingEquipmentType.self) },
      nullable: .blank
    ),  // 20: DF equipment [00310-00324]
    .string(nullable: .blank),  // 21: off-airport facility name [00325-00374]
    .string(nullable: .blank),  // 22: off-airport city [00375-00414]
    .string(nullable: .blank),  // 23: off-airport state [00415-00434]
    .string(nullable: .blank),  // 24: off-airport state/country [00435-00459]
    .string(nullable: .blank),  // 25: off-airport state code [00460-00461]
    .string(nullable: .blank),  // 26: off-airport region code [00462-00464]
    .DDMMSS(nullable: .blank),  // 27: ASR latitude formatted [00465-00478]
    .null,  // 28: ASR latitude seconds [00479-00489]
    .DDMMSS(nullable: .blank),  // 29: ASR longitude formatted [00490-00503]
    .null,  // 30: ASR longitude seconds [00504-00514]
    .DDMMSS(nullable: .blank),  // 31: DF latitude formatted [00515-00528]
    .null,  // 32: DF latitude seconds [00529-00539]
    .DDMMSS(nullable: .blank),  // 33: DF longitude formatted [00540-00553]
    .null,  // 34: DF longitude seconds [00554-00564]
    .string(nullable: .blank),  // 35: tower operator [00565-00604]
    .string(nullable: .blank),  // 36: military operator [00605-00644]
    .string(nullable: .blank),  // 37: primary approach operator [00645-00684]
    .string(nullable: .blank),  // 38: secondary approach operator [00685-00724]
    .string(nullable: .blank),  // 39: primary departure operator [00725-00764]
    .string(nullable: .blank),  // 40: secondary departure operator [00765-00804]
    .string(nullable: .blank),  // 41: tower radio call [00805-00830]
    .string(nullable: .blank),  // 42: military radio call [00831-00856]
    .string(nullable: .blank),  // 43: primary approach radio call [00857-00882]
    .string(nullable: .blank),  // 44: secondary approach radio call [00883-00908]
    .string(nullable: .blank),  // 45: primary departure radio call [00909-00934]
    .string(nullable: .blank),  // 46: secondary departure radio call [00935-00960]
    .null  // 47: blank [00961-01608]
  ])

  // TWR2 - Hours data
  private let hoursTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (TWR2)
    .string(),  //  1: facility ID [00005-00008]
    .string(nullable: .blank),  //  2: PMSV hours [00009-00208]
    .string(nullable: .blank),  //  3: MACP hours [00209-00408]
    .string(nullable: .blank),  //  4: military ops hours [00409-00608]
    .string(nullable: .blank),  //  5: primary approach hours [00609-00808]
    .string(nullable: .blank),  //  6: secondary approach hours [00809-01008]
    .string(nullable: .blank),  //  7: primary departure hours [01009-01208]
    .string(nullable: .blank),  //  8: secondary departure hours [01209-01408]
    .string(nullable: .blank)  //  9: tower hours [01409-01608]
  ])

  // TWR3 - Frequencies data (9 frequency pairs, then 9 extended frequency fields)
  private let frequenciesTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (TWR3)
    .string(),  //  1: facility ID [00005-00008]
    .string(nullable: .blank),  //  2: frequency 1 [00009-00052]
    .string(nullable: .blank),  //  3: use 1 [00053-00102]
    .string(nullable: .blank),  //  4: frequency 2 [00103-00146]
    .string(nullable: .blank),  //  5: use 2 [00147-00196]
    .string(nullable: .blank),  //  6: frequency 3 [00197-00240]
    .string(nullable: .blank),  //  7: use 3 [00241-00290]
    .string(nullable: .blank),  //  8: frequency 4 [00291-00334]
    .string(nullable: .blank),  //  9: use 4 [00335-00384]
    .string(nullable: .blank),  // 10: frequency 5 [00385-00428]
    .string(nullable: .blank),  // 11: use 5 [00429-00478]
    .string(nullable: .blank),  // 12: frequency 6 [00479-00522]
    .string(nullable: .blank),  // 13: use 6 [00523-00572]
    .string(nullable: .blank),  // 14: frequency 7 [00573-00616]
    .string(nullable: .blank),  // 15: use 7 [00617-00666]
    .string(nullable: .blank),  // 16: frequency 8 [00667-00710]
    .string(nullable: .blank),  // 17: use 8 [00711-00760]
    .string(nullable: .blank),  // 18: frequency 9 [00761-00804]
    .string(nullable: .blank),  // 19: use 9 [00805-00854]
    .null,  // 20: extended frequency 1 [00855-00914]
    .null,  // 21: extended frequency 2 [00915-00974]
    .null,  // 22: extended frequency 3 [00975-01034]
    .null,  // 23: extended frequency 4 [01035-01094]
    .null,  // 24: extended frequency 5 [01095-01154]
    .null,  // 25: extended frequency 6 [01155-01214]
    .null,  // 26: extended frequency 7 [01215-01274]
    .null,  // 27: extended frequency 8 [01275-01334]
    .null,  // 28: extended frequency 9 [01335-01394]
    .null  // 29: blank [01395-01608]
  ])

  // TWR4 - Services data
  private let servicesTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (TWR4)
    .string(),  //  1: facility ID [00005-00008]
    .string(nullable: .blank),  //  2: master airport services [00009-00108]
    .null  //  3: blank [00109-01608]
  ])

  // TWR5 - Radar data
  private let radarTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (TWR5)
    .string(),  //  1: facility ID [00005-00008]
    .generic({ try raw($0, toEnum: TerminalCommFacility.RadarType.self) }, nullable: .blank),  //  2: primary approach radar [00009-00017]
    .generic({ try raw($0, toEnum: TerminalCommFacility.RadarType.self) }, nullable: .blank),  //  3: secondary approach radar [00018-00026]
    .generic({ try raw($0, toEnum: TerminalCommFacility.RadarType.self) }, nullable: .blank),  //  4: primary departure radar [00027-00035]
    .generic({ try raw($0, toEnum: TerminalCommFacility.RadarType.self) }, nullable: .blank),  //  5: secondary departure radar [00036-00044]
    .string(nullable: .blank),  //  6: radar type 1 [00045-00054]
    .string(nullable: .blank),  //  7: radar hours 1 [00055-00254]
    .string(nullable: .blank),  //  8: radar type 2 [00255-00264]
    .string(nullable: .blank),  //  9: radar hours 2 [00265-00464]
    .string(nullable: .blank),  // 10: radar type 3 [00465-00474]
    .string(nullable: .blank),  // 11: radar hours 3 [00475-00674]
    .string(nullable: .blank),  // 12: radar type 4 [00675-00684]
    .string(nullable: .blank),  // 13: radar hours 4 [00685-00884]
    .null  // 14: blank [00885-01608]
  ])

  // TWR6 - Remark data
  private let remarkTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (TWR6)
    .string(),  //  1: facility ID [00005-00008]
    .string(nullable: .blank),  //  2: element number [00009-00013]
    .string(nullable: .blank),  //  3: remark text [00014-00813]
    .null  //  4: blank [00814-01608]
  ])

  // TWR7 - Satellite airport data
  private let satelliteTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (TWR7)
    .string(),  //  1: facility ID [00005-00008]
    .string(nullable: .blank),  //  2: satellite frequency [00009-00052]
    .string(nullable: .blank),  //  3: satellite frequency use [00053-00102]
    .string(nullable: .blank),  //  4: satellite airport site number [00103-00113]
    .string(nullable: .blank),  //  5: satellite airport ID [00114-00117]
    .string(nullable: .blank),  //  6: satellite region code [00118-00120]
    .string(nullable: .blank),  //  7: satellite state name [00121-00150]
    .string(nullable: .blank),  //  8: satellite state code [00151-00152]
    .string(nullable: .blank),  //  9: satellite city [00153-00192]
    .string(nullable: .blank),  // 10: satellite airport name [00193-00242]
    .DDMMSS(nullable: .blank),  // 11: satellite latitude formatted [00243-00256]
    .null,  // 12: satellite latitude seconds [00257-00267]
    .DDMMSS(nullable: .blank),  // 13: satellite longitude formatted [00268-00281]
    .null,  // 14: satellite longitude seconds [00282-00292]
    .string(nullable: .blank),  // 15: satellite FSS ID [00293-00296]
    .string(nullable: .blank),  // 16: satellite FSS name [00297-00326]
    .string(nullable: .blank),  // 17: master airport site number [00327-00337]
    .string(nullable: .blank),  // 18: master airport region code [00338-00340]
    .string(nullable: .blank),  // 19: master airport state name [00341-00370]
    .string(nullable: .blank),  // 20: master airport state code [00371-00372]
    .string(nullable: .blank),  // 21: master airport city [00373-00412]
    .string(nullable: .blank),  // 22: master airport name [00413-00462]
    .string(nullable: .blank),  // 23: satellite frequency (not truncated) [00463-00522]
    .null  // 24: blank [00523-01608]
  ])

  // TWR8 - Airspace data
  private let airspaceTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (TWR8)
    .string(),  //  1: facility ID [00005-00008]
    .string(nullable: .blank),  //  2: class B [00009]
    .string(nullable: .blank),  //  3: class C [00010]
    .string(nullable: .blank),  //  4: class D [00011]
    .string(nullable: .blank),  //  5: class E [00012]
    .string(nullable: .blank),  //  6: airspace hours [00013-00312]
    .null  //  7: blank [00313-01608]
  ])

  // TWR9 - ATIS data
  private let ATISTransformer = FixedWidthTransformer([
    .recordType,  //  0: record type (TWR9)
    .string(),  //  1: facility ID [00005-00008]
    .unsignedInteger(nullable: .blank),  //  2: ATIS serial number [00009-00012]
    .string(nullable: .blank),  //  3: ATIS hours [00013-00212]
    .string(nullable: .blank),  //  4: ATIS description [00213-00312]
    .string(nullable: .blank),  //  5: ATIS phone number [00313-00330]
    .null  //  6: blank [00331-01608]
  ])

  func parseValues(_ values: [String], for identifier: TWRRecordIdentifier) throws {
    switch identifier {
      case .base: try parseBaseRecord(values)
      case .hours: try parseHoursRecord(values)
      case .frequencies: try parseFrequenciesRecord(values)
      case .services: try parseServicesRecord(values)
      case .radar: try parseRadarRecord(values)
      case .remark: try parseRemarkRecord(values)
      case .satellite: try parseSatelliteRecord(values)
      case .airspace: try parseAirspaceRecord(values)
      case .atis: try parseATISRecord(values)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(terminalCommFacilities: Array(facilities.values))
  }

  /// Creates a Location from optional lat/lon, throwing if only one is present.
  private func makeLocation(
    latitude: Float?,
    longitude: Float?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        return Location(latitudeArcsec: lat, longitudeArcsec: lon)
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

    let facilityID = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)

    let position = try makeLocation(
      latitude: transformedValues[9] as? Float,
      longitude: transformedValues[11] as? Float,
      context: "terminal comm facility \(facilityID) airport position"
    )

    let asrPosition = try makeLocation(
      latitude: transformedValues[27] as? Float,
      longitude: transformedValues[29] as? Float,
      context: "terminal comm facility \(facilityID) ASR position"
    )

    let dfPosition = try makeLocation(
      latitude: transformedValues[31] as? Float,
      longitude: transformedValues[33] as? Float,
      context: "terminal comm facility \(facilityID) DF position"
    )

    let facility = TerminalCommFacility(
      facilityId: facilityID,
      airportSiteNumber: transformedValues[3] as? String,
      effectiveDateComponents: transformedValues[2] as? DateComponents,
      regionCode: transformedValues[4] as? String,
      stateName: transformedValues[5] as? String,
      stateCode: transformedValues[6] as? String,
      city: transformedValues[7] as? String,
      airportName: transformedValues[8] as? String,
      position: position,
      tieInFSSId: transformedValues[13] as? String,
      tieInFSSName: transformedValues[14] as? String,
      facilityType: transformedValues[15] as? TerminalCommFacility.FacilityType,
      hoursOfOperation: transformedValues[16] as? String,
      operationRegularity: transformedValues[17] as? TerminalCommFacility.OperationRegularity,
      masterAirportId: transformedValues[18] as? String,
      masterAirportName: transformedValues[19] as? String,
      directionFindingEquipment: transformedValues[20]
        as? TerminalCommFacility.DirectionFindingEquipmentType,
      offAirportFacilityName: transformedValues[21] as? String,
      offAirportCity: transformedValues[22] as? String,
      offAirportState: transformedValues[23] as? String,
      offAirportStateCode: transformedValues[25] as? String,
      offAirportRegionCode: transformedValues[26] as? String,
      ASRPosition: asrPosition,
      DFPosition: dfPosition,
      towerOperator: transformedValues[35] as? String,
      militaryOperator: transformedValues[36] as? String,
      primaryApproachOperator: transformedValues[37] as? String,
      secondaryApproachOperator: transformedValues[38] as? String,
      primaryDepartureOperator: transformedValues[39] as? String,
      secondaryDepartureOperator: transformedValues[40] as? String,
      towerRadioCall: transformedValues[41] as? String,
      militaryRadioCall: transformedValues[42] as? String,
      primaryApproachRadioCall: transformedValues[43] as? String,
      secondaryApproachRadioCall: transformedValues[44] as? String,
      primaryDepartureRadioCall: transformedValues[45] as? String,
      secondaryDepartureRadioCall: transformedValues[46] as? String
    )

    facilities[facilityID] = facility
  }

  private func parseHoursRecord(_ values: [String]) throws {
    let transformedValues = try hoursTransformer.applyTo(values)

    let facilityID = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    guard facilities[facilityID] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "TerminalCommFacility",
        parentID: facilityID,
        childType: "hours"
      )
    }

    facilities[facilityID]?.pmsvHours = transformedValues[2] as? String
    facilities[facilityID]?.macpHours = transformedValues[3] as? String
    facilities[facilityID]?.militaryOperationsHours = transformedValues[4] as? String
    facilities[facilityID]?.primaryApproachHours = transformedValues[5] as? String
    facilities[facilityID]?.secondaryApproachHours = transformedValues[6] as? String
    facilities[facilityID]?.primaryDepartureHours = transformedValues[7] as? String
    facilities[facilityID]?.secondaryDepartureHours = transformedValues[8] as? String
    facilities[facilityID]?.towerHours = transformedValues[9] as? String
  }

  private func parseFrequenciesRecord(_ values: [String]) throws {
    let transformedValues = try frequenciesTransformer.applyTo(values)

    let facilityID = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    guard facilities[facilityID] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "TerminalCommFacility",
        parentID: facilityID,
        childType: "frequencies"
      )
    }

    // Parse up to 9 frequency pairs
    for i in 0..<9 {
      let freqIndex = 2 + (i * 2)
      let useIndex = 3 + (i * 2)

      if let freqString = transformedValues[freqIndex] as? String, !freqString.isEmpty,
        let freqKHz = FixedWidthTransformer.parseFrequency(freqString)
      {
        let frequency = TerminalCommFacility.Frequency(
          frequencyKHz: freqKHz,
          use: transformedValues[useIndex] as? String,
          sectorization: nil
        )
        facilities[facilityID]?.frequencies.append(frequency)
      }
    }
  }

  private func parseServicesRecord(_ values: [String]) throws {
    let transformedValues = try servicesTransformer.applyTo(values)

    let facilityID = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    guard facilities[facilityID] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "TerminalCommFacility",
        parentID: facilityID,
        childType: "services"
      )
    }

    facilities[facilityID]?.masterAirportServices = transformedValues[2] as? String
  }

  private func parseRadarRecord(_ values: [String]) throws {
    let transformedValues = try radarTransformer.applyTo(values)

    let facilityID = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    guard facilities[facilityID] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "TerminalCommFacility",
        parentID: facilityID,
        childType: "radar"
      )
    }

    var equipment = [TerminalCommFacility.Radar.RadarEquipment]()

    // Parse up to 4 radar equipment entries
    for i in 0..<4 {
      let typeIndex = 6 + (i * 2)
      let hoursIndex = 7 + (i * 2)

      if let radarType = transformedValues[typeIndex] as? String, !radarType.isEmpty {
        let eq = TerminalCommFacility.Radar.RadarEquipment(
          radarType: radarType,
          hours: transformedValues[hoursIndex] as? String
        )
        equipment.append(eq)
      }
    }

    var radar = TerminalCommFacility.Radar(
      primaryApproachRadar: transformedValues[2] as? TerminalCommFacility.RadarType,
      secondaryApproachRadar: transformedValues[3] as? TerminalCommFacility.RadarType,
      primaryDepartureRadar: transformedValues[4] as? TerminalCommFacility.RadarType,
      secondaryDepartureRadar: transformedValues[5] as? TerminalCommFacility.RadarType
    )
    radar.equipment = equipment

    facilities[facilityID]?.radar = radar
  }

  private func parseRemarkRecord(_ values: [String]) throws {
    let transformedValues = try remarkTransformer.applyTo(values)

    let facilityID = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    guard facilities[facilityID] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "TerminalCommFacility",
        parentID: facilityID,
        childType: "remark"
      )
    }

    if let remark = transformedValues[3] as? String, !remark.isEmpty {
      facilities[facilityID]?.remarks.append(remark)
    }
  }

  private func parseSatelliteRecord(_ values: [String]) throws {
    let transformedValues = try satelliteTransformer.applyTo(values)

    let facilityID = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    guard facilities[facilityID] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "TerminalCommFacility",
        parentID: facilityID,
        childType: "satellite airport"
      )
    }

    // Use extended frequency if available, otherwise use truncated
    let frequencyString =
      (transformedValues[23] as? String)?.isEmpty == false
      ? transformedValues[23] as? String
      : transformedValues[2] as? String
    let frequencyKHz: UInt? =
      if let frequencyString { FixedWidthTransformer.parseFrequency(frequencyString) } else { nil }

    let satPosition = try makeLocation(
      latitude: transformedValues[11] as? Float,
      longitude: transformedValues[13] as? Float,
      context: "terminal comm facility \(facilityID) satellite airport position"
    )

    let satellite = TerminalCommFacility.SatelliteAirport(
      frequencyKHz: frequencyKHz,
      frequencyUse: transformedValues[3] as? String,
      airportSiteNumber: transformedValues[4] as? String,
      airportId: transformedValues[5] as? String,
      regionCode: transformedValues[6] as? String,
      stateName: transformedValues[7] as? String,
      stateCode: transformedValues[8] as? String,
      city: transformedValues[9] as? String,
      airportName: transformedValues[10] as? String,
      position: satPosition,
      FSSId: transformedValues[15] as? String,
      FSSName: transformedValues[16] as? String,
      masterAirportSiteNumber: transformedValues[17] as? String,
      masterAirportRegionCode: transformedValues[18] as? String,
      masterAirportStateName: transformedValues[19] as? String,
      masterAirportStateCode: transformedValues[20] as? String,
      masterAirportCity: transformedValues[21] as? String,
      masterAirportName: transformedValues[22] as? String
    )

    facilities[facilityID]?.satelliteAirports.append(satellite)
  }

  private func parseAirspaceRecord(_ values: [String]) throws {
    let transformedValues = try airspaceTransformer.applyTo(values)

    let facilityID = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    guard facilities[facilityID] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "TerminalCommFacility",
        parentID: facilityID,
        childType: "airspace"
      )
    }

    let classB = (transformedValues[2] as? String)?.uppercased() == "Y"
    let classC = (transformedValues[3] as? String)?.uppercased() == "Y"
    let classD = (transformedValues[4] as? String)?.uppercased() == "Y"
    let classE = (transformedValues[5] as? String)?.uppercased() == "Y"

    let airspace = TerminalCommFacility.Airspace(
      classB: classB,
      classC: classC,
      classD: classD,
      classE: classE,
      hours: transformedValues[6] as? String
    )

    facilities[facilityID]?.airspace = airspace
  }

  private func parseATISRecord(_ values: [String]) throws {
    let transformedValues = try ATISTransformer.applyTo(values)

    let facilityID = (transformedValues[1] as! String).trimmingCharacters(in: .whitespaces)
    guard facilities[facilityID] != nil else {
      throw ParserError.unknownParentRecord(
        parentType: "TerminalCommFacility",
        parentID: facilityID,
        childType: "ATIS"
      )
    }

    guard let serialNumber = transformedValues[2] as? UInt else {
      throw ParserError.missingRequiredField(field: "serialNumber", recordType: "TWR9")
    }

    let atis = TerminalCommFacility.ATIS(
      serialNumber: serialNumber,
      hours: transformedValues[3] as? String,
      description: transformedValues[4] as? String,
      phoneNumber: transformedValues[5] as? String
    )

    facilities[facilityID]?.ATISInfo.append(atis)
  }
}
