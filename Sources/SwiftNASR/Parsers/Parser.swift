import Foundation

protocol Parser: AnyObject {
    func prepare(distribution: Distribution) async throws
    
    func parse(data: Data) async throws

    func finish(data: NASRData) async
}

extension Parser {
    static func raw<T: RecordEnum>(_ rawValue: T.RawValue, toEnum type: T.Type) throws -> T {
        guard let val = T.for(rawValue) else {
            throw ParserError.unknownRecordEnumValue(rawValue)
        }
        return val
    }
    
    private static var offsetRx: NSRegularExpression { try! NSRegularExpression(pattern: #"^(\d+)(L|R|L\/R|B)$"#, options: []) }
    
    static func convertOffset(_ value: String) throws -> Offset {
        if value == "B" || value == "L/R" || value == "R" || value == "L" {
            return Offset(distance: 0, direction: .both)
            
        }
        if let distance = UInt(value) { return Offset(distance: distance, direction: .both) }
        
        if let match = offsetRx.firstMatch(in: value, options: [], range: value.nsRange) {
            let distanceRange = Range(match.range(at: 1), in: value)!
            let directionRange = Range(match.range(at: 2), in: value)!
            let distance = UInt(value[distanceRange])!
            var direction = String(value[directionRange])
            if direction == "L/R" { direction = "B" }
            return Offset(distance: distance, direction: Offset.Direction(rawValue: direction)!)
        }
        throw ParserError.invalidValue(value)
    }
}

enum ParserError: Swift.Error, CustomStringConvertible {
    case badData(_ reason: String)
    case unknownRecordIdentifier(_ recordIdentifier: String)
    case unknownRecordEnumValue(_ value: Sendable)
    case invalidValue(_ value: Sendable)

    public var description: String {
        switch self {
            case let .badData(reason):
                return "Invalid data: \(reason)"
            case let .unknownRecordIdentifier(identifier):
                return "Unknown record identifier '\(identifier)'"
            case let .unknownRecordEnumValue(value):
                return "Unknown record value '\(value)'"
            case let .invalidValue(value):
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
    guard let magvarNum = Int(string[string.startIndex..<string.index(before: string.endIndex)]) else {
        throw FixedWidthParserError.invalidValue(string, at: fieldIndex)
    }
    var magvar = magvarNum
    if string[string.index(string.endIndex, offsetBy: -1)] == Character("W") {
        magvar = -magvar
    }
    
    return magvar
}
