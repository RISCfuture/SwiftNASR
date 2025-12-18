import Foundation

public extension FSSCommFacility {
  /// Status effective date.
  var statusDate: Date? {
    statusDateComponents?.date
  }
}
