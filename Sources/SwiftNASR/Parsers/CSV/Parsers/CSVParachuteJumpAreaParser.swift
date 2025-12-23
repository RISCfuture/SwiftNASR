import Foundation
import StreamingCSV

/// CSV Parachute Jump Area Parser for parsing PJA_BASE.csv and PJA_CON.csv
actor CSVParachuteJumpAreaParser: CSVParser {
  var distribution: (any Distribution)?
  var progress: Progress?
  var bytesRead: Int64 = 0
  let CSVFiles = ["PJA_BASE.csv", "PJA_CON.csv"]

  var areas = [String: ParachuteJumpArea]()

  private let baseTransformer = CSVTransformer([
    .init("PJA_ID", .string()),
    .init("NAV_ID", .string(nullable: .blank)),
    .init("NAV_TYPE", .string(nullable: .blank)),
    .init("RADIAL", .float(nullable: .blank)),
    .init("DISTANCE", .float(nullable: .blank)),
    .init("NAVAID_NAME", .string(nullable: .blank)),
    .init("STATE_CODE", .string(nullable: .blank)),
    .init("CITY", .string(nullable: .blank)),
    .init("LAT_DECIMAL", .float(nullable: .blank)),
    .init("LONG_DECIMAL", .float(nullable: .blank)),
    .init("ARPT_ID", .string(nullable: .blank)),
    .init("SITE_NO", .string(nullable: .blank)),
    .init("DROP_ZONE_NAME", .string(nullable: .blank)),
    .init("MAX_ALTITUDE", .unsignedInteger(nullable: .blank)),
    .init("MAX_ALTITUDE_TYPE_CODE", .string(nullable: .blank)),
    .init("PJA_RADIUS", .float(nullable: .blank)),
    .init("CHART_REQUEST_FLAG", .boolean(nullable: .blank)),
    .init("PUBLISH_CRITERIA", .boolean(nullable: .blank)),
    .init("DESCRIPTION", .string(nullable: .blank)),
    .init("TIME_OF_USE", .string(nullable: .blank)),
    .init("FSS_ID", .string(nullable: .blank)),
    .init("FSS_NAME", .string(nullable: .blank)),
    .init("PJA_USE", .string(nullable: .blank)),
    .init("PJA_USER", .string(nullable: .blank)),
    .init("REMARK", .string(nullable: .blank))
  ])

  func prepare(distribution: Distribution) throws {
    self.distribution = distribution
  }

  func parse(data _: Data) async throws {
    // Parse PJA_BASE.csv
    try await parseCSVFile(
      filename: "PJA_BASE.csv",
      requiredColumns: ["PJA_ID"]
    ) { row in
      let t = try self.baseTransformer.applyTo(row)

      let PJAId: String = try t["PJA_ID"]

      // Parse location from decimal degrees
      let latDecimal: Float? = try t[optional: "LAT_DECIMAL"]
      let lonDecimal: Float? = try t[optional: "LONG_DECIMAL"]
      let position = try self.makeLocation(
        latitude: latDecimal,
        longitude: lonDecimal,
        context: "PJA \(PJAId) position"
      )

      // Parse altitude with type code
      let maxAltitude: Altitude? = {
        guard let altValue: UInt = try? t[optional: "MAX_ALTITUDE"] else { return nil }
        let typeCode: String = (try? t[optional: "MAX_ALTITUDE_TYPE_CODE"]) ?? "MSL"
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
        guard let useStr: String = try? t[optional: "PJA_USE"], !useStr.isEmpty else { return nil }
        return ParachuteJumpArea.UseType(rawValue: useStr.uppercased())
      }()

      // Parse times of use - split by semicolon if multiple
      let timesOfUse: [String] = {
        guard let timesStr: String = try? t[optional: "TIME_OF_USE"], !timesStr.isEmpty else {
          return []
        }
        return
          timesStr
          .split(separator: ";")
          .map { $0.trimmingCharacters(in: .whitespaces) }
          .filter { !$0.isEmpty }
      }()

      // Parse user groups - split by semicolon or comma
      let userGroups: [ParachuteJumpArea.UserGroup] = {
        guard let usersStr: String = try? t[optional: "PJA_USER"], !usersStr.isEmpty else {
          return []
        }
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
        guard let remarkStr: String = try? t[optional: "REMARK"], !remarkStr.isEmpty else {
          return []
        }
        return [remarkStr]
      }()

      // Get state code
      let stateCode: String? = try t[optional: "STATE_CODE"]

      // Combine SITE_NO and SITE_TYPE_CODE to match TXT format (e.g., "20037.1*A")
      let airportSiteNumber: String? = {
        let siteNo = ((try? t[optional: "SITE_NO"]) as String? ?? "").trimmingCharacters(
          in: .whitespaces
        )
        guard !siteNo.isEmpty else { return nil }
        // SITE_TYPE_CODE is accessed directly from row since it's not in the transformer
        if let siteTypeCode = row[ifExists: "SITE_TYPE_CODE"], !siteTypeCode.isEmpty {
          return "\(siteNo)*\(siteTypeCode)"
        }
        return siteNo
      }()

      let radial: Float? = try t[optional: "RADIAL"]
      let distance: Float? = try t[optional: "DISTANCE"]
      let radius: Float? = try t[optional: "PJA_RADIUS"]

      let area = ParachuteJumpArea(
        PJAId: PJAId,
        navaidIdentifier: try t[optional: "NAV_ID"],
        navaidFacilityTypeCode: nil,  // Not in CSV format
        navaidFacilityType: try t[optional: "NAV_TYPE"],
        azimuthFromNavaidDeg: radial.map { Double($0) },
        distanceFromNavaidNM: distance.map { Double($0) },
        navaidName: try t[optional: "NAVAID_NAME"],
        stateCode: stateCode,
        stateName: nil,  // CSV only has code, not name
        city: try t[optional: "CITY"],
        position: position,
        airportName: nil,  // CSV has airport ID, not name
        airportSiteNumber: airportSiteNumber,
        dropZoneName: try t[optional: "DROP_ZONE_NAME"],
        maxAltitude: maxAltitude,
        radiusNM: radius.map { Double($0) },
        sectionalChartingRequired: try t[optional: "CHART_REQUEST_FLAG"],
        publishedInAFD: try t[optional: "PUBLISH_CRITERIA"],
        additionalDescription: try t[optional: "DESCRIPTION"],
        FSSIdentifier: try t[optional: "FSS_ID"],
        FSSName: try t[optional: "FSS_NAME"],
        useType: useType,
        timesOfUse: timesOfUse,
        userGroups: userGroups,
        contactFacilities: [],
        remarks: remarks
      )

      self.areas[PJAId] = area
    }

    // Parse PJA_CON.csv for contact facilities
    try await parseCSVFile(
      filename: "PJA_CON.csv",
      requiredColumns: ["PJA_ID"]
    ) { row in
      let PJAId = try row["PJA_ID"]
      guard !PJAId.isEmpty, self.areas[PJAId] != nil else { return }

      let facilityId = try row.optional("FAC_ID")
      let facilityName = try row.optional("FAC_NAME")
      let locId = try row.optional("LOC_ID")
      let commFreqStr = try row.optional("COMMERCIAL_FREQ") ?? ""
      let commChartFlag = try row.optional("COMMERCIAL_CHART_FLAG") ?? ""

      // Optional fields
      let milFreqStr = try row.optional("MIL_FREQ") ?? ""
      let milChartFlag = try row.optional("MIL_CHART_FLAG") ?? ""
      let sector = try row.optional("SECTOR")
      let altitude = try row.optional("CONTACT_FREQ_ALTITUDE")

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
        facilityId: facilityId,
        facilityName: facilityName,
        relatedLocationId: locId,
        commercialFrequencyKHz: commercialFrequencyKHz,
        commercialCharted: try ParserHelpers.parseYNFlagRequired(
          commChartFlag,
          fieldName: "commercialCharted"
        ),
        militaryFrequencyKHz: militaryFrequencyKHz,
        militaryCharted: try ParserHelpers.parseYNFlagRequired(
          milChartFlag,
          fieldName: "militaryCharted"
        ),
        sector: sector,
        altitude: altitude
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
