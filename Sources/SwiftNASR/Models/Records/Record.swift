/// Conforming protocol for all data types parsed by SwiftNASR.
public protocol Record: Sendable, Codable {}

/// Conforming protocol for all top-level data types parsed by SwiftNASR.
public protocol ParentRecord: Record, Identifiable, Equatable, Hashable {}

extension ParentRecord {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

protocol RecordEnum: Record, RawRepresentable where RawValue: Hashable & Sendable {
    static var synonyms: Dictionary<RawValue, Self> { get }

    static func `for`(_ raw: RawValue) -> Self?
}

extension RecordEnum {
    static var synonyms: Dictionary<RawValue, Self> { [:] }

    static func `for`(_ raw: RawValue) -> Self? {
        return Self(rawValue: raw) ?? synonyms[raw]
    }
}

/// Protocol representing fields that remarks can be applied to.
public protocol RemarkField: Codable, Sendable, CaseIterable, Hashable {}
