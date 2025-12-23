/// Conforming protocol for all data types parsed by SwiftNASR.
public protocol Record: Sendable, Codable {}

/// Conforming protocol for all top-level data types parsed by SwiftNASR.
public protocol ParentRecord: Record, Identifiable, Equatable, Hashable {}

// swiftlint:disable missing_docs
extension ParentRecord {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
// swiftlint:enable missing_docs

protocol RecordEnum: Record, RawRepresentable where RawValue: Hashable & Sendable {
  static var synonyms: [RawValue: Self] { get }

  static func `for`(_ raw: RawValue) -> Self?
}

extension RecordEnum {
  static var synonyms: [RawValue: Self] { [:] }

  static func `for`(_ raw: RawValue) -> Self? {
    return Self(rawValue: raw) ?? synonyms[raw]
  }
}

extension RecordEnum where RawValue == String {
  /// Returns the enum value for the raw string, throwing if not found.
  static func require(_ raw: String) throws -> Self {
    guard let value = Self.for(raw) else {
      throw ParserError.unknownRecordEnumValue(raw)
    }
    return value
  }
}

/// Protocol representing fields that remarks can be applied to.
public protocol RemarkField: Codable, Sendable, CaseIterable, Hashable {}
