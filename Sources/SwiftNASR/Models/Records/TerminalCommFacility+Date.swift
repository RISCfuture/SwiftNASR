import Foundation

public extension TerminalCommFacility {
  /// Information effective date.
  var effectiveDate: Date? {
    effectiveDateComponents?.date
  }
}
