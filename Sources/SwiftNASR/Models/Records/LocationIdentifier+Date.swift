import Foundation

public extension LocationIdentifier {
  /// The effective date of this information.
  var effectiveDate: Date? {
    effectiveDateComponents?.date
  }
}
