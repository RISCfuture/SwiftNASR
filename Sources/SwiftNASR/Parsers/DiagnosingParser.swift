import Foundation

/// A ``Parser`` that accumulates field-level diagnostics (kept records with an
/// unrepresentable field) for later reporting. Record-level drops are still
/// thrown and wrapped at the parse boundary.
protocol DiagnosingParser: Parser {
  static var type: RecordType { get }
  var pendingDiagnostics: [RecordParseError] { get set }
}

extension DiagnosingParser {
  /// Returns and clears accumulated diagnostics.
  func takeDiagnostics() -> [RecordParseError] {
    defer { pendingDiagnostics.removeAll() }
    return pendingDiagnostics
  }

  /// Records a field-level diagnostic: a kept record whose `field` could not be
  /// represented from `value`.
  func recordFieldError(
    field: String,
    value: String?,
    id: String?,
    underlying: any Swift.Error & Sendable
  ) {
    pendingDiagnostics.append(
      .fieldError(
        recordType: Self.type,
        recordID: id,
        field: field,
        value: value,
        underlying: underlying
      )
    )
  }

  /// Records a field-level diagnostic, coercing an arbitrary thrown error.
  func recordFieldError(field: String, value: String?, id: String?, thrown error: any Swift.Error) {
    recordFieldError(
      field: field,
      value: value,
      id: id,
      underlying: RecordParseError.sendable(error)
    )
  }

  /// Records that a CSV row was dropped (used by the CSV per-row catch).
  func recordDroppedRow(_ error: any Swift.Error, id: String? = nil) {
    pendingDiagnostics.append(.fromThrown(recordType: Self.type, recordID: id, error))
  }

  /// Decodes a `RecordEnum` from an optional raw value.
  ///
  /// - A `nil` or blank `raw` returns `nil` with no diagnostic (the field is
  ///   legitimately absent).
  /// - A non-blank but undecodable `raw` records a `.fieldError` and returns
  ///   `nil` (the field is kept `nil`).
  func diagnose<E: RecordEnum>(
    _: E.Type,
    _ raw: String?,
    field: String,
    id: String?
  ) -> E? where E.RawValue == String {
    guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
    if let value = E.for(raw) { return value }
    recordFieldError(
      field: field,
      value: raw,
      id: id,
      underlying: ParserError.unknownRecordEnumValue(raw)
    )
    return nil
  }
}
