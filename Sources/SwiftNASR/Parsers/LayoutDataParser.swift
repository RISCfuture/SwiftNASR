import Foundation
import Combine
import Dispatch

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
    func prepare(distribution: Distribution) throws {
        formats = try formatsFor(type: Self.type, distribution: distribution)
    }
        
    func formatsFor(type: RecordType, distribution: Distribution) throws -> Array<NASRTable> {
        var formats = Array<NASRTable>()
        var error: Error? = nil
        
        try distribution.readFile(path: "Layout_Data/\(type.rawValue.lowercased())_rf.txt") { data, progress in
            do {
                try parseLine(data: data, formats: &formats)
            } catch (let lineError) {
                error = lineError
            }
        }
        
        if let error = error { throw error }
        if formats.last?.fields.isEmpty ?? false { formats.removeLast() }
        return formats
    }
    
    fileprivate func parseLine(data lineData: Data, formats: inout Array<NASRTable>) throws {
        guard let line = String(data: lineData, encoding: .ascii) else {
            throw LayoutParserError.badData("Not ASCII formatted")
        }
        
        if groupRegex.rangeOfFirstMatch(in: line, options: .anchored, range: line.nsRange).location != NSNotFound {
            if let lastFormat = formats.last {
                if !lastFormat.fields.isEmpty { formats.append(NASRTable(fields: [])) }
            } else {
                formats.append(NASRTable(fields: []))
            }
        } else if let match = fieldRegex.firstMatch(in: line, options: [], range: line.nsRange) {
            guard !formats.isEmpty else {
                throw LayoutParserError.badData("Field defined before group")
            }
            
            guard let lengthRange = Range(match.range(at: 3), in: line) else {
                throw LayoutParserError.badData("Could not find length field in string")
            }
            guard let locationRange = Range(match.range(at: 4), in: line) else {
                throw LayoutParserError.badData("Could not find location field in string")
            }
            let lengthString = line[lengthRange]
            let locationString = line[locationRange]
            guard let length = UInt(lengthString) else {
                throw LayoutParserError.badData("Length is not a number")
            }
            guard let location = UInt(locationString) else {
                throw LayoutParserError.badData("Location is not a number")
            }
            
            var identifier = ""
            if match.range(at: 5).location != NSNotFound {
                guard let identifierRange = Range(match.range(at: 5), in: line) else {
                    throw LayoutParserError.badData("Could not find identifier field in string")
                }
                identifier = String(line[identifierRange])
            }
            
            let field = NASRTableField(
                identifier: NASRTableField.Identifier(rawValue: identifier)!,
                range: (location-1)..<((location-1) + length))
            formats[formats.endIndex - 1].fields.append(field)
        }
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension LayoutDataParser {
    func preparePublisher(distribution: Distribution) -> AnyPublisher<Void, Swift.Error> {
        return formatsForPublisher(type: Self.type, distribution: distribution).map { self.formats = $0 }.eraseToAnyPublisher()
    }
    
    func formatsForPublisher(type: RecordType, distribution: Distribution) -> AnyPublisher<Array<NASRTable>, Swift.Error> {
        return distribution.readFile(path: "Layout_Data/\(type.rawValue.lowercased())_rf.txt").tryReduce(Array<NASRTable>()) { formats, data in
            return try self.parseLine(data: data, oldFormats: formats)
        }.eraseToAnyPublisher()
    }
    
    private func parseLine(data: Data, oldFormats: Array<NASRTable>) throws -> Array<NASRTable> {
        var formats = oldFormats
        try parseLine(data: data, formats: &formats)
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
