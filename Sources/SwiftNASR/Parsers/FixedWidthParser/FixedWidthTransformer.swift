import Foundation

enum Nullable {
    case notNull
    case blank
    case compact
    case sentinel(_ sentinels: Array<String>)
}

enum FixedWidthField {
    case recordType
    case null
    case string(nullable: Nullable = .notNull)
    case integer(nullable: Nullable = .notNull)
    case unsignedInteger(nullable: Nullable = .notNull)
    case float(nullable: Nullable = .notNull)
    case DDMMSS(nullable: Nullable = .notNull)
    case frequency(nullable: Nullable = .notNull)
    case boolean(trueValue: String = "Y", nullable: Nullable = .notNull)
    case datetime(formatter: DateFormatter, nullable: Nullable = .notNull)
    case fixedWidthArray(width: Int = 1, convert: ((String) throws -> Any?)? = nil, nullable: Nullable = .notNull, trim: Bool = true, emptyPlaceholders: Array<String>? = nil)
    case delimitedArray(delimiter: String, convert: (String) throws -> Any?, nullable: Nullable = .notNull, trim: Bool = true, emptyPlaceholders: Array<String>? = nil)
    case generic(_ convert: (String) throws -> Any?, nullable: Nullable = .notNull, trim: Bool = true)
}

struct FixedWidthTransformer {
    static var yearOnly: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy"
        df.timeZone = zulu
        return df
    }
    static var monthYear: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "MM/yyyy"
        df.timeZone = zulu
        return df
    }
    static var monthDayYear: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "MMddyyyy"
        df.timeZone = zulu
        return df
    }
    static var monthDayYearSlash: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "MM/dd/yyyy"
        df.timeZone = zulu
        return df
    }
    
    let fields: Array<FixedWidthField>
    
    init(_ fields: Array<FixedWidthField>) {
        self.fields = fields
    }
    
    func applyTo(_ values: Array<String>) throws -> Array<Any?> {
        return try values.enumerated().map { index, value in
            switch fields[index] {
                case .recordType: return nil
                case .null: return nil
                case let .string(nullable):
                    return try transform(value, nullable: nullable, index: index, trim: true) { $0 }
                case .integer(let nullable):
                    return try transform(value, nullable: nullable, index: index, trim: true) {
                        guard let transformed = Int($0) else {
                            throw FixedWidthParserError.invalidNumber($0, at: index)
                        }
                        return transformed
                    }
                case let .unsignedInteger(nullable):
                    return try transform(value, nullable: nullable, index: index, trim: true) {
                        guard let transformed = UInt($0) else {
                            throw FixedWidthParserError.invalidNumber($0, at: index)
                        }
                        return transformed
                    }
                case let .float(nullable):
                    return try transform(value, nullable: nullable, index: index, trim: true) {
                        guard let transformed = Float($0) else {
                            throw FixedWidthParserError.invalidNumber($0, at: index)
                        }
                        return transformed
                    }
                case let .DDMMSS(nullable):
                    return try transform(value, nullable: nullable, index: index, trim: true) {
                        guard let result = Self.parseDDMMSS($0) else {
                            throw FixedWidthParserError.invalidGeodesic($0, at: index)
                        }
                        return result
                    }
                case let .frequency(nullable):
                    return try transform(value, nullable: nullable, index: index, trim: true) {
                        guard let result = Self.parseFrequency($0) else {
                            throw FixedWidthParserError.invalidFrequency($0, at: index)
                        }
                        return result
                    }
                case let .boolean(trueValue, nullable):
                    return try transform(value, nullable: nullable, index: index, trim: true) {
                        return $0 == trueValue
                    }
                case let .datetime(formatter, nullable):
                    return try transform(value, nullable: nullable, index: index, trim: true) {
                        guard let transformed = formatter.date(from: $0) else {
                            throw FixedWidthParserError.invalidDate($0, at: index)
                        }
                        return transformed
                    }
                case let .fixedWidthArray(width, convert, nullable, trim, emptyPlaceholders):
                    if emptyPlaceholders?.contains(value) ?? false { return Array<Any?>() }
                    let array = try value.partition(by: width).map { part in
                        return try transform(part, nullable: nullable, index: index, trim: trim) {
                            if let convert {
                                do {
                                    return try convert($0)
                                } catch (let e) {
                                    throw FixedWidthParserError.conversionError($0, error: e, at: index)
                                }
                            }
                            else { return $0 }
                        }
                    }
                    guard case .compact = nullable else { return array }
                    return array.compactMap { $0 }
                case let .delimitedArray(delimiter, convert, nullable, trim, emptyPlaceholders):
                    if value.isEmpty { return Array<Any?>() }
                    if emptyPlaceholders?.contains(value) ?? false { return Array<Any?>() }

                    do {
                        let array = try value.components(separatedBy: delimiter)
                            .map { part in
                                return try transform(part, nullable: nullable, index: index, trim: trim) {
                                    do {
                                        return try convert($0)
                                    } catch (let e) {
                                        throw FixedWidthParserError.conversionError($0, error: e, at: index)
                                    }
                                }
                            }
                        guard case .compact = nullable else { return array }
                        return array.compactMap { $0 }
                    } catch (let e) {
                        throw FixedWidthParserError.conversionError(value, error: e, at: index)
                    }
                case let .generic(convert, nullable, trim):
                    return try transform(value, nullable: nullable, index: index, trim: trim) {
                        do {
                            guard let transformed = try convert($0) else {
                                throw ParserError.invalidValue($0)
                            }
                            return transformed
                        } catch (let e) {
                            throw FixedWidthParserError.conversionError($0, error: e, at: index)
                        }
                    }
            }
        }
    }

    private func transform(_ value: String, nullable: Nullable, index: Int, trim: Bool = false, transformation: (String) throws -> Any?) throws -> Any? {
        let trimmed = trim ? value.trimmingCharacters(in: .whitespaces) : value
        switch nullable {
            case .notNull:
                if trimmed.isEmpty {
                    throw FixedWidthParserError.required(at: index)
                }
                else { return try transformation(trimmed) }
            case .blank, .compact:
                if trimmed.isEmpty { return nil }
                else { return try transformation(trimmed) }
            case let .sentinel(sentinels):
                if sentinels.contains(trimmed) { return nil }
                else { return try transformation(trimmed) }
        }
    }

    private static let DDMMSSPattern = #"^(\d{2,3})-(\d{2})-(\d{2}\.\d+)([NESW])$"#
    private static var DDMMSSRegex: NSRegularExpression { return try! NSRegularExpression(pattern: DDMMSSPattern, options: []) }

    static func parseDDMMSS(_ string: String) -> Float? {
        guard let matches = DDMMSSRegex.firstMatch(in: string, options: .anchored, range: string.nsRange) else {
            return nil
        }

        let degreesRange = Range(matches.range(at: 1), in: string)!
        let minutesRange = Range(matches.range(at: 2), in: string)!
        let secondsRange = Range(matches.range(at: 3), in: string)!
        let quadrantRange = Range(matches.range(at: 4), in: string)!

        let degrees = UInt(String(string[degreesRange]))!
        let minutes = UInt(String(string[minutesRange]))!
        var seconds = Float(String(string[secondsRange]))!
        let quadrant = String(string[quadrantRange])

        let sign = (quadrant == "S" || quadrant == "W") ? -1 : 1
        seconds += Float(minutes*60)
        seconds += Float(degrees*3600)
        seconds *= Float(sign)

        return seconds
    }

    static func parseFrequency(_ string: String) -> UInt? {
        let parts = string.split(separator: Character("."))
        guard parts.count == 1 || parts.count == 2 else {
            return nil
        }
        
        if parts.count == 2 {
            let MHzString = parts[0]
            let KHzString = parts[1]
            guard let MHz = UInt(MHzString) else {
                return nil
            }
            guard let KHz = UInt(KHzString.padding(toLength: 3, withPad: "0", startingAt: 0)) else {
                return nil
            }
            return MHz*1000 + KHz
        } else {
            guard let MHz = UInt(parts[0]) else {
                return nil
            }
            return MHz*1000
        }
    }
}
