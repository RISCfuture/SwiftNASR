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
                case let .number(value): return value
            }
        }
    }
}

struct NASRTable {
    var fields: Array<NASRTableField>

    func field(forID number: String) -> NASRTableField? {
        return fields.first(where: { field -> Bool in
            guard case let .number(value) = field.identifier else { return false }
            return value == number
        })
    }

    func fieldOffset(forID number: String) -> Int? {
        return fields.firstIndex(where: { field -> Bool in
            guard case let .number(value) = field.identifier else { return false }
            return value == number
        })
    }
}

protocol LayoutDataParser: Parser {
    static var type: RecordType { get }
    var formats: Array<NASRTable> { get set }
}

extension LayoutDataParser {
    func prepare(distribution: Distribution) async throws {
        self.formats = try await formatsFor(type: Self.type, distribution: distribution)
    }

    func formatsFor(type: RecordType, distribution: Distribution) async throws -> Array<NASRTable> {
        var formats = Array<NASRTable>()
        var error: Swift.Error? = nil

        let lines: AsyncThrowingStream = await distribution.readFile(path: "Layout_Data/\(type.rawValue.lowercased())_rf.txt", withProgress: { _ in }, returningLines: { _ in })
        for try await data in lines {
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
        guard let line = String(data: lineData, encoding: .isoLatin1) else {
            throw LayoutParserError.badData("Not ISO-Latin1 formatted")
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

enum LayoutParserError: Swift.Error, CustomStringConvertible {
    case badData(_ reason: String)

    public var description: String {
        switch self {
            case let .badData(reason):
                return "Invalid data: \(reason)"
        }
    }
}
