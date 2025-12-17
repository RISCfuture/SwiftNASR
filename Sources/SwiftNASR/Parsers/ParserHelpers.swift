import Foundation

/// Common parser helper functions used by both fixed-width and CSV parsers
enum ParserHelpers {

  // MARK: - Common raw function for enums

  static func raw<T: RecordEnum>(_ rawValue: T.RawValue, toEnum _: T.Type) throws -> T {
    guard let val = T.for(rawValue) else {
      throw ParserError.unknownRecordEnumValue(rawValue)
    }
    return val
  }

  // MARK: - Navaid-specific parsers

  static func parseClassDesignator(_ code: String) throws -> Navaid.NavaidClass {
    let scanner = Scanner(string: code)
    var navaidClass = Navaid.NavaidClass()

    for altCode in Navaid.NavaidClass.AltitudeCode.allCases {
      let altPrefix = "\(altCode.rawValue)-"
      if scanner.scanString(altPrefix) != nil {
        navaidClass.altitude = altCode
        break
      }
    }

    let classDesignatorDelimiters = CharacterSet(charactersIn: "-/ ")

    isEmptyLoop: while !scanner.isAtEnd {
      _ = scanner.scanCharacters(from: classDesignatorDelimiters)

      let sortedCodes = Navaid.NavaidClass.ClassCode.allCases.sorted {
        $0.rawValue.count > $1.rawValue.count
      }
      for classCode in sortedCodes where scanner.scanString(classCode.rawValue) != nil {
        navaidClass.codes.insert(classCode)
        continue isEmptyLoop
      }

      // If we can't parse this designator, skip it
      _ = scanner.scanCharacters(from: classDesignatorDelimiters.inverted)
    }

    return navaidClass
  }

  static func parseSurveyAccuracy(_ code: String) throws -> Navaid.SurveyAccuracy {
    switch code {
      case "0": return .unknown
      case "1": return .seconds(3600)
      case "2": return .seconds(600)
      case "3": return .seconds(60)
      case "4": return .seconds(10)
      case "5": return .seconds(1)
      case "6": return .NOS
      case "7": return .thirdOrderTriangulation
      default: throw ParserError.unknownRecordEnumValue(code)
    }
  }

  static func parseTACAN(_ string: String, fieldIndex: Int) throws -> Navaid.TACANChannel {
    let channelStr = string.prefix(upTo: string.index(before: string.endIndex))
    guard let channel = UInt8(channelStr) else {
      throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
    }

    switch string.last {
      case "X": return .init(channel: channel, band: .X)
      case "Y": return .init(channel: channel, band: .Y)
      default: throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
    }
  }

  static func parseServiceVolume(_ string: String) throws -> Navaid.ServiceVolume {
    switch string {
      case "H": return .high
      case "L": return .low
      case "T": return .terminal
      case "VH", "DH": return .navaidHigh
      case "VL", "DL": return .navaidLow
      default: throw ParserError.unknownRecordEnumValue(string)
    }
  }

  static func parseHoldingPattern(_ string: String, fieldIndex: Int) throws -> HoldingPatternId {
    let name = string.prefix(80).trimmingCharacters(in: .whitespaces)
    guard let number = UInt(string.suffix(3).trimmingCharacters(in: .whitespaces)) else {
      throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
    }
    return HoldingPatternId(name: name, number: number)
  }

  // MARK: - Common parsers

  static func parseMagVar(_ string: String, fieldIndex: Int) throws -> Int {
    guard let magvarNum = Int(string[string.startIndex..<string.index(before: string.endIndex)])
    else {
      throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
    }
    var magvar = magvarNum
    if string[string.index(string.endIndex, offsetBy: -1)] == Character("W") {
      magvar = -magvar
    }

    return magvar
  }

  // MARK: - Airport-specific parsers

  static func parseAirportFacilityType(_ code: String) throws -> Airport.FacilityType {
    switch code {
      case "A": return .airport
      case "B": return .balloonport
      case "C": return .seaport
      case "G": return .gliderport
      case "H": return .heliport
      case "U": return .ultralight
      default: throw ParserError.unknownRecordEnumValue(code)
    }
  }
}

// MARK: - Global convenience functions for backwards compatibility

func raw<T: RecordEnum>(_ rawValue: T.RawValue, toEnum type: T.Type) throws -> T {
  return try ParserHelpers.raw(rawValue, toEnum: type)
}

func parseClassDesignator(_ code: String) throws -> Navaid.NavaidClass {
  return try ParserHelpers.parseClassDesignator(code)
}

func parseSurveyAccuracy(_ code: String) throws -> Navaid.SurveyAccuracy {
  return try ParserHelpers.parseSurveyAccuracy(code)
}

func parseTACAN(_ string: String, fieldIndex: Int) throws -> Navaid.TACANChannel {
  return try ParserHelpers.parseTACAN(string, fieldIndex: fieldIndex)
}

func parseServiceVolume(_ string: String) throws -> Navaid.ServiceVolume {
  return try ParserHelpers.parseServiceVolume(string)
}

func parseHoldingPattern(_ string: String, fieldIndex: Int) throws -> HoldingPatternId {
  return try ParserHelpers.parseHoldingPattern(string, fieldIndex: fieldIndex)
}

func parseMagVar(_ string: String, fieldIndex: Int) throws -> Int {
  return try ParserHelpers.parseMagVar(string, fieldIndex: fieldIndex)
}

/// Strips owner type prefix (like "F-", "O-", "N-", "R-", "A-") from CSV owner/operator names
/// CSV format combines owner type code with name (e.g., "F-FEDERAL AVIATION ADMIN")
/// TXT format has owner type and name in separate fields
func stripOwnerTypePrefix(_ string: String) -> String {
  // Owner type prefixes are single uppercase letter followed by hyphen
  // F=Federal, O=Other, N=Navy, R=Army, A=Air Force
  if string.count >= 2,
    string[string.index(string.startIndex, offsetBy: 1)] == "-",
    let firstChar = string.first, firstChar.isUppercase
  {
    return String(string.dropFirst(2))
  }
  return string
}

// MARK: - Decimal Degrees Coordinate Parsing

/// Parse latitude string (DD-MM-SS.SSSSH format) to decimal degrees
func parseDecimalDegreesLatitude(_ str: String) throws -> Double? {
  guard !str.isEmpty else { return nil }

  let isNorth = str.hasSuffix("N")
  let isSouth = str.hasSuffix("S")
  var working = str
  if isNorth || isSouth {
    working = String(str.dropLast())
  }

  // Try DD-MM-SS.SSSSH format first
  if working.contains("-") {
    let parts = working.split(separator: "-")
    guard parts.count >= 3 else { return nil }

    guard let degrees = Double(parts[0]),
      let minutes = Double(parts[1]),
      let seconds = Double(parts[2])
    else { return nil }

    var lat = degrees + (minutes / 60.0) + (seconds / 3600.0)
    if isSouth { lat = -lat }
    return lat
  }

  // Try packed format DDMMSS.SSSS
  guard working.count >= 6 else { return nil }
  guard let degrees = Double(working.prefix(2)),
    let minutes = Double(working.dropFirst(2).prefix(2)),
    let seconds = Double(working.dropFirst(4))
  else { return nil }

  var lat = degrees + (minutes / 60.0) + (seconds / 3600.0)
  if isSouth { lat = -lat }
  return lat
}

/// Parse longitude string (DDD-MM-SS.SSSSH format) to decimal degrees
func parseDecimalDegreesLongitude(_ str: String) throws -> Double? {
  guard !str.isEmpty else { return nil }

  let isWest = str.hasSuffix("W")
  let isEast = str.hasSuffix("E")
  var working = str
  if isWest || isEast {
    working = String(str.dropLast())
  }

  // Try DDD-MM-SS.SSSSH format first
  if working.contains("-") {
    let parts = working.split(separator: "-")
    guard parts.count >= 3 else { return nil }

    guard let degrees = Double(parts[0]),
      let minutes = Double(parts[1]),
      let seconds = Double(parts[2])
    else { return nil }

    var lon = degrees + (minutes / 60.0) + (seconds / 3600.0)
    if isWest { lon = -lon }
    return lon
  }

  // Try packed format DDDMMSS.SSSS
  guard working.count >= 7 else { return nil }
  guard let degrees = Double(working.prefix(3)),
    let minutes = Double(working.dropFirst(3).prefix(2)),
    let seconds = Double(working.dropFirst(5))
  else { return nil }

  var lon = degrees + (minutes / 60.0) + (seconds / 3600.0)
  if isWest { lon = -lon }
  return lon
}
