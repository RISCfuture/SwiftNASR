import Foundation

public extension ATSAirway {
  /// Chart/publication effective date.
  var effectiveDate: Date? {
    effectiveDateComponents.date
  }
}
