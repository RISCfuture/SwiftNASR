import Foundation

public extension Runway {
  /// The date the runway length was determined.
  var lengthSourceDate: Date? {
    lengthSourceDateComponents?.date
  }
}
