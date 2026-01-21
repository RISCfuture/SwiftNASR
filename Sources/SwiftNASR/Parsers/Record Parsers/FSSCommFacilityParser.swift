import Foundation

/// Parser for COM (FSS Communications Facilities) files.
///
/// These files contain information about Flight Service Station communication outlets,
/// including Remote Communication Outlets (RCOs) and their associated frequencies.
/// Records are 693 characters fixed-width with a single record type.
///
/// Note: This parser uses hardcoded field positions because the FAA layout file
/// does not contain group separators required by the layout parser.
actor FixedWidthFSSCommFacilityParser: Parser {
  // Field positions (0-indexed start, length)
  private static let fields: [(Int, Int)] = [
    (0, 4),  // outlet identifier
    (4, 7),  // outlet type
    (11, 4),  // navaid identifier
    (15, 2),  // navaid type
    (17, 26),  // navaid city
    (43, 20),  // navaid state
    (63, 26),  // navaid name
    (89, 14),  // navaid latitude
    (103, 14),  // navaid longitude
    (117, 26),  // outlet city
    (143, 20),  // outlet state
    (163, 20),  // region name
    (183, 3),  // region code
    (186, 14),  // outlet latitude
    (200, 14),  // outlet longitude
    (214, 26),  // outlet call
    (240, 144),  // frequencies (16 x 9)
    (384, 4),  // FSS identifier
    (388, 30),  // FSS name
    (418, 4),  // alternate FSS identifier
    (422, 30),  // alternate FSS name
    (452, 60),  // operational hours (3 x 20)
    (512, 1),  // owner code
    (513, 69),  // owner name
    (582, 1),  // operator code
    (583, 69),  // operator name
    (652, 8),  // charts (4 x 2)
    (660, 2),  // time zone
    (662, 20),  // status
    (682, 11)  // status date
  ]

  var facilities = [FSSCommFacility]()

  private let transformer = ByteTransformer([
    .string(),  // 0 outlet identifier (4)
    .string(nullable: .blank),  // 1 outlet type (7)
    .string(nullable: .blank),  // 2 navaid identifier (4)
    .string(nullable: .blank),  // 3 navaid type (2)
    .string(nullable: .blank),  // 4 navaid city (26)
    .string(nullable: .blank),  // 5 navaid state (20)
    .string(nullable: .blank),  // 6 navaid name (26)
    .generic({ try parseDecimalDegreesLatitude($0) }, nullable: .blank),  // 7 navaid latitude (14)
    .generic({ try parseDecimalDegreesLongitude($0) }, nullable: .blank),  // 8 navaid longitude (14)
    .string(nullable: .blank),  // 9 outlet city (26)
    .string(nullable: .blank),  // 10 outlet state (20)
    .string(nullable: .blank),  // 11 region name (20)
    .string(nullable: .blank),  // 12 region code (3)
    .generic({ try parseDecimalDegreesLatitude($0) }, nullable: .blank),  // 13 outlet latitude (14)
    .generic({ try parseDecimalDegreesLongitude($0) }, nullable: .blank),  // 14 outlet longitude (14)
    .string(nullable: .blank),  // 15 outlet call (26)
    .string(nullable: .blank),  // 16 frequencies (144)
    .string(nullable: .blank),  // 17 FSS identifier (4)
    .string(nullable: .blank),  // 18 FSS name (30)
    .string(nullable: .blank),  // 19 alternate FSS identifier (4)
    .string(nullable: .blank),  // 20 alternate FSS name (30)
    .string(nullable: .blank),  // 21 operational hours (60)
    .string(nullable: .blank),  // 22 owner code (1)
    .string(nullable: .blank),  // 23 owner name (69)
    .string(nullable: .blank),  // 24 operator code (1)
    .string(nullable: .blank),  // 25 operator name (69)
    .string(nullable: .blank),  // 26 charts (8)
    .string(nullable: .blank),  // 27 time zone (2)
    .string(nullable: .blank),  // 28 status (20)
    .dateComponents(format: .dayMonthYear, nullable: .blank)  // 29 status date (11)
  ])

  func prepare(distribution _: Distribution) throws {
    // No layout file parsing needed - using hardcoded field positions
  }

  func parse(data: Data) throws {
    guard data.count >= 4 else {
      throw ParserError.truncatedRecord(
        recordType: "COM",
        expectedMinLength: 4,
        actualLength: data.count
      )
    }

    // Extract field values as byte slices using hardcoded positions
    let bytes = [UInt8](data)
    let values = Self.fields.map { start, length -> ArraySlice<UInt8> in
      guard start < bytes.count else { return bytes[0..<0] }
      let endIndex = min(start + length, bytes.count)
      return bytes[start..<endIndex]
    }

    let t = try transformer.applyTo(values)

    let rawOutletId: String = try t[0]
    let outletId = rawOutletId.trimmingCharacters(in: .whitespaces)
    guard !outletId.isEmpty else {
      throw ParserError.missingRequiredField(field: "outletIdentifier", recordType: "COM")
    }

    let outletTypeStr: String = (try t[optional: 1] ?? "").trimmingCharacters(in: .whitespaces)

    // Parse frequencies (16 x 9 characters)
    let frequenciesStr: String = try t[optional: 16] ?? ""
    var frequencies = [FSSCommFacility.Frequency]()
    for i in 0..<16 {
      let start = i * 9
      if start < frequenciesStr.count {
        let endIndex = min(start + 9, frequenciesStr.count)
        var freqStr = String(
          frequenciesStr[
            frequenciesStr.index(
              frequenciesStr.startIndex,
              offsetBy: start
            )..<frequenciesStr.index(
              frequenciesStr.startIndex,
              offsetBy: endIndex
            )
          ]
        ).trimmingCharacters(in: .whitespaces)
        if !freqStr.isEmpty {
          // Check for usage suffix (e.g., "R" for receive-only)
          var use: FSSCommFacility.Frequency.Use?
          if freqStr.hasSuffix("R") {
            use = .receiveOnly
            freqStr = String(freqStr.dropLast())
          }
          // Convert MHz to kHz (multiply by 1000)
          if let mhz = Double(freqStr) {
            let khz = UInt(mhz * 1000)
            frequencies.append(FSSCommFacility.Frequency(frequencyKHz: khz, use: use))
          }
        }
      }
    }

    // Parse operational hours (3 x 20 characters, joined since lines break mid-word)
    let hoursStr: String = try t[optional: 21] ?? ""
    let opHours: String? = {
      let joined = (0..<3).map { i -> String in
        let start = i * 20
        guard start < hoursStr.count else { return "" }
        let endIndex = min(start + 20, hoursStr.count)
        return String(
          hoursStr[
            hoursStr.index(
              hoursStr.startIndex,
              offsetBy: start
            )..<hoursStr.index(
              hoursStr.startIndex,
              offsetBy: endIndex
            )
          ]
        ).trimmingCharacters(in: .whitespaces)
      }
      .joined()
      return joined.isEmpty ? nil : joined
    }()

    // Parse charts (4 x 2 characters)
    let chartsStr: String = try t[optional: 26] ?? ""
    var charts = [String]()
    for i in 0..<4 {
      let start = i * 2
      if start < chartsStr.count {
        let endIndex = min(start + 2, chartsStr.count)
        let chart = String(
          chartsStr[
            chartsStr.index(
              chartsStr.startIndex,
              offsetBy: start
            )..<chartsStr.index(
              chartsStr.startIndex,
              offsetBy: endIndex
            )
          ]
        ).trimmingCharacters(in: .whitespaces)
        if !chart.isEmpty {
          charts.append(chart)
        }
      }
    }

    let navaidPosition = try makeLocation(
      latitude: try t[optional: 7],
      longitude: try t[optional: 8],
      context: "FSS comm facility \(outletId) navaid position"
    )

    let outletPosition = try makeLocation(
      latitude: try t[optional: 13],
      longitude: try t[optional: 14],
      context: "FSS comm facility \(outletId) outlet position"
    )

    let navaidTypeCode: String? = try t[optional: 3]
    let tzCode: String? = try t[optional: 27]
    let statusStr: String? = try t[optional: 28]

    let facility = FSSCommFacility(
      outletIdentifier: outletId,
      outletType: FSSCommFacility.OutletType(rawValue: outletTypeStr),
      navaidIdentifier: try t[optional: 2],
      navaidType: navaidTypeCode.flatMap { Navaid.FacilityType.for($0) },
      navaidCity: try t[optional: 4],
      navaidState: try t[optional: 5],
      navaidName: try t[optional: 6],
      navaidPosition: navaidPosition,
      outletCity: try t[optional: 9],
      outletState: try t[optional: 10],
      regionName: try t[optional: 11],
      regionCode: try t[optional: 12],
      outletPosition: outletPosition,
      outletCall: try t[optional: 15],
      frequencies: frequencies,
      FSSIdentifier: try t[optional: 17],
      FSSName: try t[optional: 18],
      alternateFSSIdentifier: try t[optional: 19],
      alternateFSSName: try t[optional: 20],
      operationalHours: opHours,
      ownerCode: try t[optional: 22],
      ownerName: try t[optional: 23],
      operatorCode: try t[optional: 24],
      operatorName: try t[optional: 25],
      charts: charts,
      timeZone: tzCode.flatMap { StandardTimeZone(rawValue: $0) },
      status: statusStr.flatMap { FSS.Status(rawValue: $0) },
      statusDateComponents: try t[optional: 29]
    )

    facilities.append(facility)
  }

  func finish(data: NASRData) async {
    await data.finishParsing(FSSCommFacilities: facilities)
  }

  /// Creates a Location from optional lat/lon (decimal degrees), throwing if only one is present.
  /// Converts decimal degrees to arc-seconds for Location storage.
  private func makeLocation(
    latitude: Double?,
    longitude: Double?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        // Convert decimal degrees to arc-seconds (multiply by 3600)
        return Location(latitudeArcsec: Float(lat * 3600), longitudeArcsec: Float(lon * 3600))
      case (.none, .none):
        return nil
      default:
        throw ParserError.invalidLocation(
          latitude: latitude.map { Float($0) },
          longitude: longitude.map { Float($0) },
          context: context
        )
    }
  }
}
