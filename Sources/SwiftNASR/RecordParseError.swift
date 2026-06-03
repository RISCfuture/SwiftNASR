import Foundation

/// Whether parsing should continue after a ``RecordParseError`` is reported.
public enum ParseDisposition: Sendable {
  /// Continue parsing subsequent records.
  case proceed
  /// Stop parsing; ``NASR/parse(_:withProgress:errorHandler:)`` returns `false`.
  case abort
}

/// A problem encountered while parsing a single record from a NASR distribution.
///
/// Reported through the `errorHandler` of
/// ``NASR/parse(_:withProgress:errorHandler:)``. A ``recordError`` means the
/// record could not be constructed and was omitted; a ``fieldError`` means the
/// record was kept but one field could not be represented and was set to `nil`
/// (or a repeated sub-element was omitted).
public enum RecordParseError: Swift.Error, Sendable {
  /// A record couldn't be constructed and was omitted from the results.
  case recordError(
    recordType: RecordType,
    recordID: String?,
    underlying: any Swift.Error & Sendable
  )

  /// A record was kept, but a field couldn't be represented.
  case fieldError(
    recordType: RecordType,
    recordID: String?,
    field: String,
    value: String?,
    underlying: any Swift.Error & Sendable
  )

  /// Coerces an arbitrary error to `any Swift.Error & Sendable`, preserving the
  /// concrete type for known module errors and falling back to a description.
  /// (Sendable is a marker protocol, so a runtime `as? any Swift.Error & Sendable`
  /// cast is impossible; this switch over concrete types is required.)
  static func sendable(_ error: any Swift.Error) -> any Swift.Error & Sendable {
    switch error {
      case let e as ParserError: return e
      case let e as FixedWidthParserError: return e
      case let e as SwiftNASR.Error: return e
      default: return AnySendableError(error)
    }
  }

  /// Wraps an arbitrary thrown error into a ``recordError``.
  static func fromThrown(
    recordType: RecordType,
    recordID: String?,
    _ error: any Swift.Error
  ) -> Self {
    .recordError(recordType: recordType, recordID: recordID, underlying: sendable(error))
  }
}

/// A `Sendable` wrapper that preserves only an error's description, used as a
/// fallback for thrown errors whose concrete type is not a known module error.
struct AnySendableError: Swift.Error, Sendable, CustomStringConvertible {
  let description: String

  init(_ error: any Swift.Error) { description = String(describing: error) }
}

extension RecordParseError: LocalizedError {
  public var errorDescription: String? {
    switch self {
      case let .recordError(recordType, recordID, underlying):
        let id = recordID.map { " \u{2018}\($0)\u{2019}" } ?? ""
        return String(
          localized: "Dropped \(recordType.rawValue) record\(id): \(String(describing: underlying))"
        )
      case let .fieldError(recordType, recordID, field, value, underlying):
        let id = recordID.map { " \u{2018}\($0)\u{2019}" } ?? ""
        let val = value.map { " (value \u{2018}\($0)\u{2019})" } ?? ""
        return String(
          localized:
            "Unrepresentable field \u{2018}\(field)\u{2019}\(val) in \(recordType.rawValue) record\(id): \(String(describing: underlying))"
        )
    }
  }
}
