import Foundation

public extension MilitaryTrainingRoute {
  /// Publication effective date.
  var effectiveDate: Date? {
    effectiveDateComponents?.date
  }
}
