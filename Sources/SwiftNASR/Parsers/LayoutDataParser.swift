import Foundation
@preconcurrency import RegexBuilder

private final class FieldParser: Sendable {
    private let lengthRef = Reference<UInt>()
    private let locationRef = Reference<UInt>()
    private let identifierRef = Reference<NASRTableField.Identifier>()

    private var fieldRx: some RegexComponent {
        Regex {
            Anchor.startOfSubject
            CharacterClass.anyOf("LR")
            OneOrMore(.whitespace)
            ChoiceOf {
                "N"
                "AN"
            }
            OneOrMore(.whitespace)
            Capture(as: lengthRef) { OneOrMore(.digit) } transform: { .init($0)! }
            OneOrMore(.whitespace)
            Capture(as: locationRef) { OneOrMore(.digit) } transform: { .init($0)! }
            OneOrMore(.whitespace)
            Capture(as: identifierRef) {
                Optionally {
                    ChoiceOf {
                        OneOrMore(.word)
                        "N/A"
                    }
                }
            } transform: { .init(rawValue: String($0))! }
            OneOrMore(.whitespace)
        }
    }

    private var groupRx: some RegexComponent {
        Regex {
            Anchor.startOfSubject
            OneOrMore("*")
            Anchor.endOfSubject
        }
    }

    func isGroup(line: String) throws -> Bool {
        try groupRx.regex.wholeMatch(in: line) != nil
    }

    func parseLine(_ line: String) throws -> Match? {
        guard let match = try fieldRx.regex.firstMatch(in: line) else { return nil }
        let length = match[lengthRef],
            location = match[locationRef],
            identifier = match[identifierRef]
        return .init(length: length, location: location, identifier: identifier)
    }

    struct Match {
        let length: UInt
        let location: UInt
        let identifier: NASRTableField.Identifier

        var range: Range<UInt> { (location - 1)..<((location - 1) + length) }
    }
}

private let fieldParser = FieldParser()

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
    var fields: [NASRTableField]

    func field(forID number: String) -> NASRTableField? {
        return fields.first { field -> Bool in
            guard case let .number(value) = field.identifier else { return false }
            return value == number
        }
    }

    func fieldOffset(forID number: String) -> Int? {
        return fields.firstIndex { field -> Bool in
            guard case let .number(value) = field.identifier else { return false }
            return value == number
        }
    }
}

protocol LayoutDataParser: Parser {
    static var type: RecordType { get }
    var formats: [NASRTable] { get set }
}

extension LayoutDataParser {
    func prepare(distribution: Distribution) async throws {
        self.formats = try await formatsFor(type: Self.type, distribution: distribution)
    }

    func formatsFor(type: RecordType, distribution: Distribution) async throws -> [NASRTable] {
        var formats = [NASRTable]()
        var lineError: Swift.Error?

        let lines: AsyncThrowingStream = await distribution.readFile(path: "Layout_Data/\(type.rawValue.lowercased())_rf.txt", withProgress: { _ in }, returningLines: { _ in })
        for try await data in lines {
            do {
                try parseLine(data: data, formats: &formats)
            } catch {
                lineError = error
                break
            }
        }

        if let lineError { throw lineError }
        if formats.last?.fields.isEmpty ?? false { formats.removeLast() }
        return formats
    }

    private func parseLine(data lineData: Data, formats: inout [NASRTable]) throws {
        guard let line = String(data: lineData, encoding: .isoLatin1) else {
            throw LayoutParserError.badData("Not ISO-Latin1 formatted")
        }

        if try fieldParser.isGroup(line: line) {
            if let lastFormat = formats.last {
                if !lastFormat.fields.isEmpty { formats.append(NASRTable(fields: [])) }
            } else {
                formats.append(NASRTable(fields: []))
            }
        } else if let match = try fieldParser.parseLine(line) {
            guard !formats.isEmpty else {
                throw LayoutParserError.badData("Field defined before group")
            }

            let field = NASRTableField(
                identifier: match.identifier,
                range: match.range)
            formats[formats.endIndex - 1].fields.append(field)
        }
    }
}

enum LayoutParserError: Swift.Error, CustomStringConvertible {
    case badData(_ reason: String)

    var description: String {
        switch self {
            case let .badData(reason):
                return "Invalid data: \(reason)"
        }
    }
}
