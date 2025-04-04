/**
 This class contains the remarks applied to a NASR record. Remarks are written
 either by the FAA officials managing the data or the person submitting the data
 to the FAA. Remarks can be applied to a record as a whole, or to a specific
 field within the record.
 
 The `F` type will be a ``RemarkField`` enum representing all the fields in a
 record type that can have a remark applied to them.
 */

public struct Remarks<F: RemarkField>: Record {

    /// All remarks added to the record.
    public var remarks = [Remark<F>]()

    /// Remarks applied to a record as a whole.
    var general: [String] {
        var remarks = [String]()

        for remark in self.remarks {
            guard case let .general(content) = remark else { break }
            remarks.append(content)
        }

        return remarks
    }

    /**
     Gets the remarks for a specific field.
     
     - Parameter field: The field to get remarks for.
     - Returns: The remarks for that field (if any).
     */
    public func forField(_ field: F) -> [Remark<F>] {
        var remarks = [Remark<F>]()

        for remark in self.remarks {
            switch remark {
                case let .field(remarkField, _):
                    if field == remarkField {
                        remarks.append(remark)
                    }
                case let .fuel(remarkField, _, _):
                    if field == remarkField {
                        remarks.append(remark)
                    }
                default: break
            }
        }

        return remarks
    }

    public mutating func append(_ remark: Remark<F>) {
        remarks.append(remark)
    }
}

/**
 Contains remarks about a record or a field within a record.
 */

public enum Remark<F: RemarkField>: Record {

    /// A remark that applies to the record in general.
    case general(_ content: String)

    /// A remark that applies to a specific field.
    case field(field: F, content: String)

    /// A remark that applies to a specific fuel type (e.g., 100LL).
    case fuel(field: F, fuel: Airport.FuelType, content: String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let type = Kinds(rawValue: try container.decode(String.self, forKey: .type)) else {
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.type, in: container, debugDescription: "invalid enum value")
        }
        switch type {
            case .general:
                let content = try container.decode(String.self, forKey: .content)
                self = .general(content)
            case .field:
                let field = try container.decode(F.self, forKey: .field)
                let content = try container.decode(String.self, forKey: .content)
                self = .field(field: field, content: content)
            case .fuel:
                let field = try container.decode(F.self, forKey: .field)
                let fuel = try container.decode(Airport.FuelType.self, forKey: .fuel)
                let content = try container.decode(String.self, forKey: .content)
                self = .fuel(field: field, fuel: fuel, content: content)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case let .general(content):
                try container.encode(Kinds.general.rawValue, forKey: .type)
                try container.encode(content, forKey: .content)
            case let .field(field, content):
                try container.encode(Kinds.field.rawValue, forKey: .type)
                try container.encode(field, forKey: .field)
                try container.encode(content, forKey: .content)
            case let .fuel(field, fuel, content):
                try container.encode(Kinds.fuel.rawValue, forKey: .type)
                try container.encode(field, forKey: .field)
                try container.encode(fuel, forKey: .fuel)
                try container.encode(content, forKey: .content)
        }
    }

    private enum Kinds: String {
        case general, field, fuel
    }

    private enum CodingKeys: CodingKey {
        case type, content, field, fuel
    }
}
