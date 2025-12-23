import Foundation

enum ARTCCRecordIdentifier: String {
  case generalData = "AFF1"
  case remarks = "AFF2"
  case frequencies = "AFF3"
  case frequencyRemarks = "AFF4"
}

public struct ARTCCKey: Hashable {
  let ID: String
  let location: String
  let type: ARTCC.FacilityType

  init(center: ARTCC) {
    ID = center.code
    location = center.locationName
    type = center.type
  }

  init(values: FixedWidthTransformedRow) throws {
    ID = try values[1]
    location = try values[2]
    type = try values[3]
  }

  init(ID: String, location: String, type: ARTCC.FacilityType) {
    self.ID = ID
    self.location = location
    self.type = type
  }
}

actor FixedWidthARTCCParser: FixedWidthParser {
  typealias RecordIdentifier = ARTCCRecordIdentifier

  static let type: RecordType = .ARTCCFacilities
  static let layoutFormatOrder: [RecordIdentifier] = [
    .generalData, .remarks, .frequencies, .frequencyRemarks
  ]

  var recordTypeRange: Range<UInt> { 0..<4 }
  var formats = [NASRTable]()
  var ARTCCs = [ARTCCKey: ARTCC]()

  private let generalTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type
    .string(),  //  1 identifier

    .string(),  //  2 name
    .string(),  //  3 location name
    .string(nullable: .blank),  //  4 cross reference

    .recordEnum(ARTCC.FacilityType.self),  //  5 facility type
    .null,  //  6 effective date
    .null,  //  7 state name
    .string(nullable: .blank),  //  8 state PO code

    .DDMMSS(nullable: .blank),  //  9 latitude - formatted
    .null,  // 10 latitude - decimal
    .DDMMSS(nullable: .blank),  // 11 longitude - formatted
    .null,  // 12 longitude - decimal
    .string(nullable: .blank),  // 13 ICAO ID
    .null  // 14 blank
  ])

  private let remarksTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 ARTCC ID
    .string(),  // 2 ARTCC location
    .recordEnum(ARTCC.FacilityType.self),  // 3 facility type
    .unsignedInteger(),  // 4 sequence number
    .string(),  // 5 remark
    .null  // 6 blank
  ])

  private let frequencyTransformer = FixedWidthTransformer([
    .recordType,  //  0 record type
    .string(),  //  1 ARTCC ID
    .string(),  //  2 ARTCC location
    .recordEnum(ARTCC.FacilityType.self),  //  3 facility type

    .frequency(),  //  4 frequency
    .delimitedArray(delimiter: "/") { try ARTCC.CommFrequency.Altitude.require($0) },  //  5 altitude
    .string(nullable: .blank),  //  6 special usage name
    .boolean(nullable: .blank),  //  7 RCAG freq charted flag

    .string(nullable: .blank),  //  8 landing facility LID
    .null,  //  9 state name
    .null,  // 10 state PO code
    .null,  // 11 city name
    .null,  // 12 airport name
    .null,  // 13 airport latitude - formatted
    .null,  // 14 airport latitude - seconds
    .null,  // 15 airport longitude - formatted
    .null  // 16 airport longitude - seconds
  ])

  private let frequencyRemarksTransformer = FixedWidthTransformer([
    .recordType,  // 0 record type
    .string(),  // 1 ARTCC ID
    .string(),  // 2 ARTCC location
    .recordEnum(ARTCC.FacilityType.self),  // 3 facility type
    .frequency(),  // 4 frequency
    .unsignedInteger(),  // 5 sequence number
    .string(),  // 6 remark
    .null  // 7 blank
  ])

  func parseValues(_ values: [String], for identifier: ARTCCRecordIdentifier) throws {
    switch identifier {
      case .generalData: try parseGeneralRecord(values)
      case .remarks: try parseRemarks(values)
      case .frequencies: try parseFrequency(values)
      case .frequencyRemarks: try parseFrequencyRemarks(values)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(ARTCCs: Array(ARTCCs.values))
  }

  private func parseGeneralRecord(_ values: [String]) throws {
    let t = try generalTransformer.applyTo(values)

    var location: Location?
    if let lat: Float = try t[optional: 9], let lon: Float = try t[optional: 11] {
      location = Location(latitudeArcsec: lat, longitudeArcsec: lon)
    }

    let center = ARTCC(
      code: try t[1],
      ICAOID: try t[optional: 13],
      type: try t[5],
      name: try t[2],
      alternateName: try t[optional: 4],
      locationName: try t[3],
      stateCode: try t[optional: 8],
      location: location
    )

    ARTCCs[ARTCCKey(center: center)] = center
  }

  private func parseRemarks(_ values: [String]) throws {
    let t = try remarksTransformer.applyTo(values),
      remarkText: String = try t[5]
    try updateARTCC(t) { center in
      center.remarks.append(.general(remarkText))
    }
  }

  private func parseFrequency(_ values: [String]) throws {
    let t = try frequencyTransformer.applyTo(values)

    try updateARTCC(t) { center in
      let frequency = ARTCC.CommFrequency(
        frequencyKHz: try t[4],
        altitude: try t[5],
        specialUsageName: try t[optional: 6],
        remoteOutletFrequencyCharted: try t[optional: 7],
        associatedAirportCode: try t[optional: 8]
      )
      center.frequencies.append(frequency)
    }
  }

  private func parseFrequencyRemarks(_ values: [String]) throws {
    let t = try frequencyRemarksTransformer.applyTo(values),
      freqKHz: UInt = try t[4],
      remarkText: String = try t[6]

    try updateARTCC(t) { center in
      guard
        let freqIndex = center.frequencies.firstIndex(where: { $0.frequencyKHz == freqKHz })
      else {
        throw Error.unknownARTCCFrequency(freqKHz, ARTCC: center)
      }
      center.frequencies[freqIndex].remarks.append(.general(remarkText))
    }
  }

  private func updateARTCC(
    _ values: FixedWidthTransformedRow,
    process: (inout ARTCC) throws -> Void
  ) throws {
    let key = try ARTCCKey(values: values)
    guard var center = ARTCCs[key] else {
      throw Error.unknownARTCC(key.ID)
    }

    try process(&center)
    ARTCCs[key] = center
  }
}
