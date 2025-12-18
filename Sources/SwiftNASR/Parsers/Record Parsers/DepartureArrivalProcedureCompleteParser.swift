import Foundation

/// Parser for STARDP (Departure/Arrival Procedures Complete) files.
///
/// This parser uses the same format as SSD but represents the complete
/// comprehensive set of STAR and DP procedures, including multiple main
/// body procedures and procedures without computer IDs.
class FixedWidthDepartureArrivalProcedureCompleteParser: LayoutDataParser {
  static let type = RecordType.departureArrivalProceduresComplete

  var formats = [NASRTable]()
  var procedures = [String: DepartureArrivalProcedure]()

  func parse(data: Data) throws {
    guard let line = String(data: data, encoding: .isoLatin1) else {
      throw ParserError.badData("Invalid ISO-Latin1 encoding in STARDP record")
    }
    guard line.count >= 52 else {
      throw ParserError.truncatedRecord(
        recordType: "STARDP",
        expectedMinLength: 52,
        actualLength: line.count
      )
    }

    // Determine procedure type from first character
    let typeChar = String(line.prefix(1))
    guard let procedureType = DepartureArrivalProcedure.ProcedureType.for(typeChar) else {
      throw ParserError.unknownRecordEnumValue(typeChar)
    }

    // Extract fields based on layout (same as SSD)
    let sequenceNumber = String(line.substring(0, 5)).trimmingCharacters(in: .whitespaces)
    let fixTypeCode = String(line.substring(10, 2)).trimmingCharacters(in: .whitespaces)
    let latitudeStr = String(line.substring(13, 8)).trimmingCharacters(in: .whitespaces)
    let longitudeStr = String(line.substring(21, 9)).trimmingCharacters(in: .whitespaces)
    let identifier = String(line.substring(30, 6)).trimmingCharacters(in: .whitespaces)
    let icaoRegion = String(line.substring(36, 2)).trimmingCharacters(in: .whitespaces)
    let computerCode = String(line.substring(38, 13)).trimmingCharacters(in: .whitespaces)
    let name = String(line.substring(51, 110)).trimmingCharacters(in: .whitespaces)
    let airwaysNavaids =
      line.count >= 223
      ? String(line.substring(161, 62)).trimmingCharacters(in: .whitespaces) : nil

    let fixType = DepartureArrivalProcedure.FixType.for(fixTypeCode)
    let latitude = parseLatitude(latitudeStr)
    let longitude = parseLongitude(longitudeStr)

    let procedureKey = "\(procedureType.rawValue)\(sequenceNumber)"

    // Get existing procedure or create new one
    var procedure =
      procedures[procedureKey]
      ?? DepartureArrivalProcedure(
        procedureType: procedureType,
        sequenceNumber: sequenceNumber,
        computerCode: computerCode.isEmpty || computerCode == "NOT ASSIGNED" ? nil : computerCode,
        name: name.isEmpty ? nil : name
      )

    let isNewProcedure = procedures[procedureKey] == nil

    if fixType == .adaptedAirport {
      // This is an adapted airport record
      guard let position = makeLocation(latitude: latitude, longitude: longitude) else {
        throw ParserError.missingRequiredField(
          field: "position",
          recordType: "STARDP AdaptedAirport"
        )
      }
      guard !identifier.isEmpty else {
        throw ParserError.missingRequiredField(
          field: "identifier",
          recordType: "STARDP AdaptedAirport"
        )
      }
      let airport = DepartureArrivalProcedure.AdaptedAirport(
        position: position,
        identifier: identifier
      )
      procedure.adaptedAirports.append(airport)
    } else if !isNewProcedure && !computerCode.isEmpty && computerCode != "NOT ASSIGNED"
      && procedure.computerCode != computerCode
    {
      // This is a transition (has a different computer code)
      var transition = DepartureArrivalProcedure.Transition(
        computerCode: computerCode,
        name: name.isEmpty ? nil : name,
        points: []
      )

      // Add first point of transition
      if let fixTypeValue = fixType {
        guard let position = makeLocation(latitude: latitude, longitude: longitude) else {
          throw ParserError.missingRequiredField(field: "position", recordType: "STARDP Point")
        }
        guard !identifier.isEmpty else {
          throw ParserError.missingRequiredField(field: "identifier", recordType: "STARDP Point")
        }
        let point = DepartureArrivalProcedure.Point(
          fixType: fixTypeValue,
          position: position,
          identifier: identifier,
          ICAORegionCode: icaoRegion.isEmpty ? nil : icaoRegion,
          airwaysNavaids: airwaysNavaids?.isEmpty == false ? airwaysNavaids : nil
        )
        transition.points.append(point)
      }

      procedure.transitions.append(transition)
    } else if !procedure.transitions.isEmpty {
      // Add point to current transition
      guard let fixTypeValue = fixType else {
        throw ParserError.missingRequiredField(field: "fixType", recordType: "STARDP Point")
      }
      guard let position = makeLocation(latitude: latitude, longitude: longitude) else {
        throw ParserError.missingRequiredField(field: "position", recordType: "STARDP Point")
      }
      guard !identifier.isEmpty else {
        throw ParserError.missingRequiredField(field: "identifier", recordType: "STARDP Point")
      }
      let point = DepartureArrivalProcedure.Point(
        fixType: fixTypeValue,
        position: position,
        identifier: identifier,
        ICAORegionCode: icaoRegion.isEmpty ? nil : icaoRegion,
        airwaysNavaids: airwaysNavaids?.isEmpty == false ? airwaysNavaids : nil
      )
      procedure.transitions[procedure.transitions.count - 1].points.append(point)
    } else if let fixTypeValue = fixType {
      // Add point to main body
      guard let position = makeLocation(latitude: latitude, longitude: longitude) else {
        throw ParserError.missingRequiredField(field: "position", recordType: "STARDP Point")
      }
      guard !identifier.isEmpty else {
        throw ParserError.missingRequiredField(field: "identifier", recordType: "STARDP Point")
      }
      let point = DepartureArrivalProcedure.Point(
        fixType: fixTypeValue,
        position: position,
        identifier: identifier,
        ICAORegionCode: icaoRegion.isEmpty ? nil : icaoRegion,
        airwaysNavaids: airwaysNavaids?.isEmpty == false ? airwaysNavaids : nil
      )
      procedure.points.append(point)
    }

    procedures[procedureKey] = procedure
  }

  func finish(data: NASRData) async {
    await data.finishParsing(departureArrivalProceduresComplete: Array(procedures.values))
  }

  // MARK: - Helper methods

  /// Creates a Location from optional lat/lon. Both must be present or absent.
  private func makeLocation(latitude: Float?, longitude: Float?) -> Location? {
    switch (latitude, longitude) {
      case let (.some(lat), .some(lon)):
        return Location(latitudeDeg: Double(lat), longitudeDeg: Double(lon))
      case (.none, .none):
        return nil
      case let (.some(lat), .none):
        // Log but don't throw - this parser is more lenient due to data quality issues
        return Location(latitudeDeg: Double(lat), longitudeDeg: nil)
      case let (.none, .some(lon)):
        // Log but don't throw - this parser is more lenient due to data quality issues
        return Location(latitudeDeg: nil, longitudeDeg: Double(lon))
    }
  }

  /// Parse latitude in format XDDMMSST (e.g., N3353229) to decimal degrees.
  private func parseLatitude(_ str: String) -> Float? {
    guard str.count >= 7 else { return nil }

    let declination = str.prefix(1)
    let degrees = Float(str.substring(1, 2)) ?? 0
    let minutes = Float(str.substring(3, 2)) ?? 0
    let seconds = Float(str.substring(5, 2)) ?? 0
    let tenths = str.count >= 8 ? (Float(str.substring(7, 1)) ?? 0) / 10.0 : 0

    var decimal = degrees + (minutes / 60.0) + ((seconds + tenths) / 3600.0)
    if declination == "S" {
      decimal = -decimal
    }
    return decimal
  }

  /// Parse longitude in format XDDDMMSST (e.g., W11651012) to decimal degrees.
  private func parseLongitude(_ str: String) -> Float? {
    guard str.count >= 8 else { return nil }

    let declination = str.prefix(1)
    let degrees = Float(str.substring(1, 3)) ?? 0
    let minutes = Float(str.substring(4, 2)) ?? 0
    let seconds = Float(str.substring(6, 2)) ?? 0
    let tenths = str.count >= 9 ? (Float(str.substring(8, 1)) ?? 0) / 10.0 : 0

    var decimal = degrees + (minutes / 60.0) + ((seconds + tenths) / 3600.0)
    if declination == "W" {
      decimal = -decimal
    }
    return decimal
  }
}
