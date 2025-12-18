import Foundation

// MARK: - FSS.CommFacility

public extension FSS.CommFacility {
  /// The date that the current status was last updated.
  var statusDate: Date? {
    statusDateComponents?.date
  }
}
