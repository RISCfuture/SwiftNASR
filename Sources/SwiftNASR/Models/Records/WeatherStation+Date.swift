import Foundation

public extension WeatherStation {
  /// The date the station was commissioned or decommissioned.
  var commissionDate: Date? {
    commissionDateComponents?.date
  }
}
