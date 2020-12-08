import Foundation

fileprivate let fieldPattern = #"^([LR]) +(N|AN) +(\d+) +(\d+) +([A-Z0-9]+|N\/A)? +.+"#
fileprivate let fieldRegex = try! NSRegularExpression(pattern: fieldPattern, options: [])

fileprivate let groupPattern = #"^\*+$"#
fileprivate let groupRegex = try! NSRegularExpression(pattern: groupPattern, options: [])

fileprivate let lengthRange = 5...8
fileprivate let locationRange = 10...14

struct NASRTableField {
    let identifier: Identifier
    let range: Range<UInt>
    
    enum Identifier: RawRepresentable {
        typealias RawValue = String

        case none
        case databaseLocatorID
        case number(_ value: String)
        
        init?(rawValue: String) {
            switch rawValue {
                case "NONE", "": self = .none
                case "N/A": self = .none
                case "DLID": self = .databaseLocatorID
                default: self = .number(rawValue)
            }
        }
        
        var rawValue: String {
            switch self {
                case .none: return "NONE"
                case .databaseLocatorID: return "DLID"
                case .number(let value): return value
            }
        }
    }
}

struct NASRTable {
    var fields: Array<NASRTableField>
    
    func field(forID number: String) -> NASRTableField? {
        return fields.first(where: { field -> Bool in
            switch field.identifier {
                case .number(let value): return value == number
                default: return false
            }
        })
    }
    
    func fieldOffset(forID number: String) -> Int? {
        return fields.firstIndex(where: { field -> Bool in
            switch field.identifier {
                case .number(let value): return value == number
                default: return false
            }
        })
    }
}

protocol LayoutDataParser: Parser {
    static var type: RecordType { get }
    var formats: Array<NASRTable> { get set }
}

extension LayoutDataParser {
    mutating func prepare(distribution: Distribution) throws {
        formats = try self.formatsFor(type: Self.type, distribution: distribution)
    }
        
    func formatsFor(type: RecordType, distribution: Distribution) throws -> Array<NASRTable> {
        var error: Swift.Error? = nil
        
        var formats = Array<NASRTable>()
        
        try distribution.readFile(path: "Layout_Data/\(type.rawValue.lowercased())_rf.txt") { lineData in
            guard let line = String(data: lineData, encoding: .ascii) else {
                error = LayoutParserError.badData("Not ASCII formatted")
                return
            }
            
            if groupRegex.rangeOfFirstMatch(in: line, options: .anchored, range: line.nsRange).location != NSNotFound {
                if let lastFormat = formats.last {
                    if !lastFormat.fields.isEmpty { formats.append(NASRTable(fields: [])) }
                } else {
                    formats.append(NASRTable(fields: []))
                }
            } else if let match = fieldRegex.firstMatch(in: line, options: [], range: line.nsRange) {
                guard !formats.isEmpty else {
                    error = LayoutParserError.badData("Field defined before group")
                    return
                }
                
                guard let lengthRange = Range(match.range(at: 3), in: line) else {
                    error = LayoutParserError.badData("Could not find length field in string")
                    return
                }
                guard let locationRange = Range(match.range(at: 4), in: line) else {
                    error = LayoutParserError.badData("Could not find location field in string")
                    return
                }
                let lengthString = line[lengthRange]
                let locationString = line[locationRange]
                guard let length = UInt(lengthString) else {
                    error = LayoutParserError.badData("Length is not a number")
                    return
                }
                guard let location = UInt(locationString) else {
                    error = LayoutParserError.badData("Location is not a number")
                    return
                }
                
                var identifier = ""
                if match.range(at: 5).location != NSNotFound {
                    guard let identifierRange = Range(match.range(at: 5), in: line) else {
                        error = LayoutParserError.badData("Could not find identifier field in string")
                        return
                    }
                    identifier = String(line[identifierRange])
                }
                
                let field = NASRTableField(
                    identifier: NASRTableField.Identifier(rawValue: identifier)!,
                    range: (location-1)..<((location-1) + length))
                formats[formats.endIndex - 1].fields.append(field)
            }
        }
        
        if let error = error { throw error }
        if formats.last?.fields.isEmpty ?? false { formats.removeLast() }
        return formats
    }
}

enum LayoutParserError: Swift.Error, CustomStringConvertible {
    case badData(_ reason: String)
    
    public var description: String {
        switch self {
            case .badData(let reason):
                return "Invalid data: \(reason)"
        }
    }
}
