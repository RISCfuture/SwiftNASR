import Foundation

public extension Navaid {
  /// The epoch date of the magnetic variation data.
  var magneticVariationEpoch: Date? {
    magneticVariationEpochComponents?.date
  }
}
