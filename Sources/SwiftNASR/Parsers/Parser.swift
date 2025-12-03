import Foundation
@preconcurrency import RegexBuilder

protocol Parser: AnyObject {
  func prepare(distribution: Distribution) async throws

  func parse(data: Data) async throws

  func finish(data: NASRData) async
}

final class OffsetParser: Sendable {
  private let distanceRef = Reference<UInt?>()
  private let directionRef = Reference<Offset.Direction>()
  private var rx: some RegexComponent {
    Regex {
      Anchor.startOfSubject
      Capture(as: distanceRef) {
        Optionally { OneOrMore(.digit) }
      } transform: {
        .init($0)
      }
      Capture(as: directionRef) {
        Optionally {
          ChoiceOf {
            "L"
            "R"
            "L/R"
            "B"
          }
        }
      } transform: {
        .from(string: String($0)) ?? .both
      }
      Anchor.endOfSubject
    }
  }

  func parse(_ string: String) throws -> Offset? {
    guard let match = try rx.regex.wholeMatch(in: string) else { return nil }
    let distance = match[distanceRef]
    let direction = match[directionRef]
    guard let distance else { return .init(distance: 0, direction: .both) }
    return .init(distance: distance, direction: direction)
  }
}

extension Parser {
  static func raw<T: RecordEnum>(_ rawValue: T.RawValue, toEnum _: T.Type) throws -> T {
    guard let val = T.for(rawValue) else {
      throw ParserError.unknownRecordEnumValue(rawValue)
    }
    return val
  }
}

enum ParserError: Swift.Error, CustomStringConvertible {
  case badData(_ reason: String)
  case unknownRecordIdentifier(_ recordIdentifier: String)
  case unknownRecordEnumValue(_ value: Sendable)
  case invalidValue(_ value: Sendable)

  var description: String {
    switch self {
      case .badData(let reason):
        return "Invalid data: \(reason)"
      case .unknownRecordIdentifier(let identifier):
        return "Unknown record identifier '\(identifier)'"
      case .unknownRecordEnumValue(let value):
        return "Unknown record value '\(value)'"
      case .invalidValue(let value):
        return "Invalid value '\(value)'"
    }
  }
}

func parserFor(recordType: RecordType) -> Parser {
  switch recordType {
    case .airports: return AirportParser()
    case .states: return StateParser()
    case .ARTCCFacilities: return ARTCCParser()
    case .flightServiceStations: return FSSParser()
    case .navaids: return NavaidParser()
    default:
      preconditionFailure("No parser for \(recordType)")
  }
}

func parseMagVar(_ string: String, fieldIndex: Int) throws -> Int {
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
