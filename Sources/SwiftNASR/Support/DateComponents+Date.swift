import Foundation

extension DateComponents {
  private static let gregorianUTC: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()

  /// Converts these date components to a Date using Gregorian calendar and UTC timezone.
  var date: Date? {
    Self.gregorianUTC.date(from: self)
  }
}
