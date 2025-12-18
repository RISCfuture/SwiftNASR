import Foundation

public extension Hold {
  /// Effective date of the holding pattern.
  var effectiveDate: Date? {
    effectiveDateComponents?.date
  }
}
