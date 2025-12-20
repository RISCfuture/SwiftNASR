import Foundation
import StreamingCSV

/// CSV Parachute Jump Area Parser for parsing PJA_BASE.csv and PJA_CON.csv
actor CSVParachuteJumpAreaParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["PJA_BASE.csv", "PJA_CON.csv"]

  var areas = [String: ParachuteJumpArea]()

  // CSV field indices for PJA_BASE.csv (0-based)
  // EFF_DATE(0), PJA_ID(1), NAV_ID(2), NAV_TYPE(3), RADIAL(4), DISTANCE(5),
  // NAVAID_NAME(6), STATE_CODE(7), CITY(8), LATITUDE(9), LAT_DECIMAL(10),
  // LONGITUDE(11), LONG_DECIMAL(12), ARPT_ID(13), SITE_NO(14), SITE_TYPE_CODE(15),
  // DROP_ZONE_NAME(16), MAX_ALTITUDE(17), MAX_ALTITUDE_TYPE_CODE(18), PJA_RADIUS(19),
  // CHART_REQUEST_FLAG(20), PUBLISH_CRITERIA(21), DESCRIPTION(22), TIME_OF_USE(23),
  // FSS_ID(24), FSS_NAME(25), PJA_USE(26), VOLUME(27), PJA_USER(28), REMARK(29)
  private let baseFieldMapping: [Int] = [
    0,  //  0: EFF_DATE -> ignored
    1,  //  1: PJA_ID
    2,  //  2: NAV_ID
    3,  //  3: NAV_TYPE (facility type description)
    4,  //  4: RADIAL (azimuth from navaid)
    5,  //  5: DISTANCE (from navaid)
    6,  //  6: NAVAID_NAME
    7,  //  7: STATE_CODE
    8,  //  8: CITY
    10,  //  9: LAT_DECIMAL
    12,  // 10: LONG_DECIMAL
    13,  // 11: ARPT_ID
    14,  // 12: SITE_NO
    16,  // 13: DROP_ZONE_NAME
    17,  // 14: MAX_ALTITUDE
    18,  // 15: MAX_ALTITUDE_TYPE_CODE
    19,  // 16: PJA_RADIUS
    20,  // 17: CHART_REQUEST_FLAG
    21,  // 18: PUBLISH_CRITERIA
    22,  // 19: DESCRIPTION
    23,  // 20: TIME_OF_USE
    24,  // 21: FSS_ID
    25,  // 22: FSS_NAME
    26,  // 23: PJA_USE
    28,  // 24: PJA_USER
    29  // 25: REMARK
  ]

  private let baseTransformer = CSVTransformer([
    .null,  //  0: EFF_DATE -> ignored
    .string(),  //  1: PJA_ID
    .string(nullable: .blank),  //  2: NAV_ID
    .string(nullable: .blank),  //  3: NAV_TYPE (facility type description)
    .float(nullable: .blank),  //  4: RADIAL (azimuth)
    .float(nullable: .blank),  //  5: DISTANCE
    .string(nullable: .blank),  //  6: NAVAID_NAME
    .string(nullable: .blank),  //  7: STATE_CODE
    .string(nullable: .blank),  //  8: CITY
    .float(nullable: .blank),  //  9: LAT_DECIMAL
    .float(nullable: .blank),  // 10: LONG_DECIMAL
    .string(nullable: .blank),  // 11: ARPT_ID (airport identifier, not name)
    .string(nullable: .blank),  // 12: SITE_NO
    .string(nullable: .blank),  // 13: DROP_ZONE_NAME
    .unsignedInteger(nullable: .blank),  // 14: MAX_ALTITUDE
    .string(nullable: .blank),  // 15: MAX_ALTITUDE_TYPE_CODE (MSL, AGL, UNR)
    .float(nullable: .blank),  // 16: PJA_RADIUS
    .boolean(nullable: .blank),  // 17: CHART_REQUEST_FLAG (Y/N)
    .boolean(nullable: .blank),  // 18: PUBLISH_CRITERIA (Y/N)
    .string(nullable: .blank),  // 19: DESCRIPTION
    .string(nullable: .blank),  // 20: TIME_OF_USE
    .string(nullable: .blank),  // 21: FSS_ID
    .string(nullable: .blank),  // 22: FSS_NAME
    .string(nullable: .blank),  // 23: PJA_USE (CIVIL, MILITARY, JOINT)
    .string(nullable: .blank),  // 24: PJA_USER
    .string(nullable: .blank)  // 25: REMARK
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse PJA_BASE.csv
    try await parseCSVFile(filename: "PJA_BASE.csv", expectedFieldCount: 30) { fields in
      guard fields.count >= 27 else { return }

      // Map CSV fields to transformer indices
      var mappedFields = [String](repeating: "", count: 26)
      for (transformerIndex, csvIndex) in self.baseFieldMapping.enumerated()
      where csvIndex < fields.count {
        mappedFields[transformerIndex] = fields[csvIndex]
      }

      let transformedValues = try self.baseTransformer.applyTo(
        mappedFields,
        indices: Array(0..<26)
      )

      let PJAId = transformedValues[1] as! String

      // Parse location from decimal degrees
      let position = try self.makeLocation(
        latitude: transformedValues[9] as? Float,
        longitude: transformedValues[10] as? Float,
        context: "PJA \(PJAId) position"
      )

      // Parse altitude with type code
      let maxAltitude: Altitude? = {
        guard let altValue = transformedValues[14] as? UInt else { return nil }
        let typeCode = transformedValues[15] as? String ?? "MSL"
        let datum: Altitude.Datum =
          switch typeCode.uppercased() {
            case "AGL": .AGL
            case "UNR": .MSL  // Unrestricted treated as MSL
            default: .MSL
          }
        return Altitude(altValue, datum: datum)
      }()

      // Parse use type
      let useType: ParachuteJumpArea.UseType? = {
        guard let useStr = transformedValues[23] as? String, !useStr.isEmpty else { return nil }
        return ParachuteJumpArea.UseType(rawValue: useStr.uppercased())
      }()

      // Parse times of use - split by semicolon if multiple
      let timesOfUse: [String] = {
        guard let timesStr = transformedValues[20] as? String, !timesStr.isEmpty else { return [] }
        return
          timesStr
          .split(separator: ";")
          .map { $0.trimmingCharacters(in: .whitespaces) }
          .filter { !$0.isEmpty }
      }()

      // Parse user groups - split by semicolon or comma
      let userGroups: [ParachuteJumpArea.UserGroup] = {
        guard let usersStr = transformedValues[24] as? String, !usersStr.isEmpty else { return [] }
        // Try splitting by semicolon first, then by comma if no semicolons
        let separator: Character = usersStr.contains(";") ? ";" : ","
        return usersStr.split(separator: separator).compactMap { groupStr in
          let name = groupStr.trimmingCharacters(in: .whitespaces)
          guard !name.isEmpty else { return nil }
          return ParachuteJumpArea.UserGroup(name: name, description: nil)
        }
      }()

      // Parse remarks - single field in CSV
      let remarks: [String] = {
        guard let remarkStr = transformedValues[25] as? String, !remarkStr.isEmpty else {
          return []
        }
        return [remarkStr]
      }()

      // Get state name from state code - CSV doesn't have state name separately
      // We'll leave stateName nil since we only have the code
      let stateCode = transformedValues[7] as? String

      // Combine SITE_NO and SITE_TYPE_CODE to match TXT format (e.g., "20037.1*A")
      let airportSiteNumber: String? = {
        let siteNo = (transformedValues[12] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !siteNo.isEmpty else { return nil }
        // SITE_TYPE_CODE is at CSV index 15
        if fields.count > 15 {
          let siteTypeCode = fields[15].trimmingCharacters(in: .whitespaces)
          if !siteTypeCode.isEmpty {
            return "\(siteNo)*\(siteTypeCode)"
          }
        }
        return siteNo
      }()

      let area = ParachuteJumpArea(
        PJAId: PJAId,
        navaidIdentifier: transformedValues[2] as? String,
        navaidFacilityTypeCode: nil,  // Not in CSV format
        navaidFacilityType: transformedValues[3] as? String,
        azimuthFromNavaidDeg: (transformedValues[4] as? Float).map { Double($0) },
        distanceFromNavaidNM: (transformedValues[5] as? Float).map { Double($0) },
        navaidName: transformedValues[6] as? String,
        stateCode: stateCode,
        stateName: nil,  // CSV only has code, not name
        city: transformedValues[8] as? String,
        position: position,
        airportName: nil,  // CSV has airport ID, not name
        airportSiteNumber: airportSiteNumber,
        dropZoneName: transformedValues[13] as? String,
        maxAltitude: maxAltitude,
        radiusNM: (transformedValues[16] as? Float).map { Double($0) },
        sectionalChartingRequired: transformedValues[17] as? Bool,
        publishedInAFD: transformedValues[18] as? Bool,
        additionalDescription: transformedValues[19] as? String,
        FSSIdentifier: transformedValues[21] as? String,
        FSSName: transformedValues[22] as? String,
        useType: useType,
        timesOfUse: timesOfUse,
        userGroups: userGroups,
        contactFacilities: [],
        remarks: remarks
      )

      self.areas[PJAId] = area
    }

    // Parse PJA_CON.csv for contact facilities
    // Columns: EFF_DATE(0), PJA_ID(1), FAC_ID(2), FAC_NAME(3), LOC_ID(4),
    // COMMERCIAL_FREQ(5), COMMERCIAL_CHART_FLAG(6), MIL_FREQ(7), MIL_CHART_FLAG(8),
    // SECTOR(9), CONTACT_FREQ_ALTITUDE(10)
    try await parseCSVFile(filename: "PJA_CON.csv", expectedFieldCount: 11) { fields in
      guard fields.count >= 7 else { return }

      let PJAId = fields[1].trimmingCharacters(in: .whitespaces)
      guard !PJAId.isEmpty, self.areas[PJAId] != nil else { return }

      let facilityId = fields[2].trimmingCharacters(in: .whitespaces)
      let facilityName = fields[3].trimmingCharacters(in: .whitespaces)
      let locId = fields[4].trimmingCharacters(in: .whitespaces)
      let commFreqStr = fields[5].trimmingCharacters(in: .whitespaces)
      let commChartFlag = fields[6].trimmingCharacters(in: .whitespaces)

      // Optional fields
      let milFreqStr = fields.count > 7 ? fields[7].trimmingCharacters(in: .whitespaces) : ""
      let milChartFlag = fields.count > 8 ? fields[8].trimmingCharacters(in: .whitespaces) : ""
      let sector = fields.count > 9 ? fields[9].trimmingCharacters(in: .whitespaces) : ""
      let altitude = fields.count > 10 ? fields[10].trimmingCharacters(in: .whitespaces) : ""

      // Parse frequencies - CSV has them in MHz with decimal (e.g., "126.5")
      let commercialFrequencyKHz: UInt? = {
        guard let freq = Double(commFreqStr) else { return nil }
        return UInt(freq * 1000)
      }()

      let militaryFrequencyKHz: UInt? = {
        guard !milFreqStr.isEmpty, let freq = Double(milFreqStr) else { return nil }
        return UInt(freq * 1000)
      }()

      let facility = ParachuteJumpArea.ContactFacility(
        facilityId: facilityId.isEmpty ? nil : facilityId,
        facilityName: facilityName.isEmpty ? nil : facilityName,
        relatedLocationId: locId.isEmpty ? nil : locId,
        commercialFrequencyKHz: commercialFrequencyKHz,
        commercialCharted: commChartFlag == "Y",
        militaryFrequencyKHz: militaryFrequencyKHz,
        militaryCharted: milChartFlag == "Y",
        sector: sector.isEmpty ? nil : sector,
        altitude: altitude.isEmpty ? nil : altitude
      )

      self.areas[PJAId]?.contactFacilities.append(facility)
    }
  }

  func finish(data: NASRData) async {
    await data.finishParsing(parachuteJumpAreas: Array(areas.values))
  }

  /// Creates a Location from optional lat/lon (decimal degrees), throwing if only one is present.
  /// Converts decimal degrees to arc-seconds for Location storage.
  private func makeLocation(
    latitude: Float?,
    longitude: Float?,
    context: String
  ) throws -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        // Convert decimal degrees to arc-seconds (multiply by 3600)
        return Location(latitudeArcsec: lat * 3600, longitudeArcsec: lon * 3600)
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
}
