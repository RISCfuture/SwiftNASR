import Foundation

protocol FixedWidthParser: LayoutDataParser {
    associatedtype RecordIdentifier: RawRepresentable, Equatable where RecordIdentifier.RawValue == String

    static var layoutFormatOrder: [RecordIdentifier] { get }

    var recordTypeRange: Range<UInt> { get }
    var formats: [NASRTable] { get set }

    func parseValues(_ values: [String], for identifier: RecordIdentifier) throws
}

extension FixedWidthParser {
    var recordTypeRange: Range<UInt> { 0..<3 }

    func format(forRecordIdentifier identifier: RecordIdentifier) -> NASRTable {
        guard let index = Self.layoutFormatOrder.firstIndex(of: identifier) else {
            preconditionFailure("No configured layout format for '\(identifier.rawValue)'")
        }
        return formats[index]
    }

    func parse(data: Data) throws {
        let recordIdentifier = try readIdentifier(data: data)
        let layoutFormat = format(forRecordIdentifier: recordIdentifier)
        let values = layoutFormat.fields.map { field in
            return String(data: data[field.range], encoding: .isoLatin1)!
        }

        try parseValues(values, for: recordIdentifier)
    }

    @available(*, unavailable)
    func finish(data _: NASRData) {
        fatalError("must be implemented by subclasses")
    }

    private func readIdentifier(data: Data) throws -> RecordIdentifier {
        guard let identifierString = String(data: data[recordTypeRange], encoding: .isoLatin1) else {
            throw ParserError.badData("Invalid ISO-Latin1 character")
        }
        guard let identifier = RecordIdentifier(rawValue: identifierString) else {
            throw ParserError.badData("Invalid record identifier '\(identifierString)'")
        }

        return identifier
    }
}

enum FixedWidthParserError: Swift.Error, CustomStringConvertible {
    case required(at: Int)
    case invalidNumber(_ value: String, at: Int)
    case invalidDate(_ value: String, at: Int)
    case invalidFrequency(_ value: String, at: Int)
    case invalidGeodesic(_ value: String, at: Int)
    case conversionError(_ value: String, error: Swift.Error, at: Int)
    case invalidValue(_ value: String, at: Int)

    var description: String {
        switch self {
            case let .required(field):
                return "Field #\(field) is required"
            case let .invalidNumber(value, field):
                return "Field #\(field) contains invalid number '\(value)'"
            case let .invalidDate(value, field):
                return "Field #\(field) contains invalid date '\(value)'"
            case let .invalidFrequency(value, field):
                return "Field #\(field) contains invalid frequency '\(value)'"
            case let .invalidGeodesic(value, field):
                return "Field #\(field) contains invalid geodesic '\(value)'"
            case let .conversionError(_, error, field):
                return "Field #\(field) contains invalid value: \(error)"
            case let .invalidValue(value, field):
                return "Field #\(field) contains invalid value '\(value)'"
        }
    }
}
