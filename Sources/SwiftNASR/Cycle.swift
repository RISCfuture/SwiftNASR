import Foundation

/**
 NASR data is distributed on a 56-day cycle. The Cycle class represents one such
 time period. Cycles are defined by the first day of their effectivity period.
 */

public struct Cycle: Codable, CustomStringConvertible, Sendable, Identifiable, Equatable, Hashable {
  /// The earliest reference cycle (not necessarily the earliest cycle for
  /// which data is available, but the earliest representable date for a
  /// cycle).
  public static let datum = Self(year: 2020, month: 12, day: 3)

  /// `true` if this cycle's effectivity period includes the current date.
  public static var current: Self { effectiveCycle(for: Date())! }

  private static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zulu
    return calendar
  }

  /// The length of time a cycle is effective for.
  public static let cycleDuration: DateComponents = .init(day: 28)
  private static let negativeCycleDuration: DateComponents = .init(day: -28)

  /// The year of the first date of the cycle.
  public let year: UInt

  /// The month of the first date of the cycle.
  public let month: UInt8

  /// The day of the first date of the cycle.
  public let day: UInt8

  /// A `DateComponents` object representing the first effective day of this
  /// cycle.
  public var dateComponents: DateComponents {
    var dc = DateComponents()
    dc.year = Int(year)
    dc.month = Int(month)
    dc.day = Int(day)
    return dc
  }

  /// A `Date` object representing the first effective day of this cycle.
  public var date: Date? { Self.calendar.date(from: dateComponents) }

  /// The last date when this cycle is effective.
  public var endDate: Date? {
    guard let date else { return nil }
    return Self.calendar.date(byAdding: Self.cycleDuration, to: date)
  }

  /// The range of times when this cycle is effective.
  public var dateRange: DateInterval? {
    guard let date else { return nil }
    guard let endDate else { return nil }

    return DateInterval(start: date, end: endDate)
  }

  /// Whether or not this cycle is currently effective.
  public var isEffective: Bool { contains(Date()) }

  /// The next active cycle following this one.
  public var next: Self? {
    guard let endDate else { return nil }
    let components = Self.calendar.dateComponents([.year, .month, .day], from: endDate)
    guard let year = components.year,
      let month = components.month,
      let day = components.day
    else { return nil }
    return Self(year: UInt(year), month: UInt8(month), day: UInt8(day))
  }

  /// The previously active cycle before this one.
  public var previous: Self? {
    guard let date else { return nil }
    guard let prevDate = Self.calendar.date(byAdding: Self.negativeCycleDuration, to: date) else {
      return nil
    }
    let components = Self.calendar.dateComponents([.year, .month, .day], from: prevDate)
    guard let year = components.year,
      let month = components.month,
      let day = components.day
    else { return nil }
    return Self(year: UInt(year), month: UInt8(month), day: UInt8(day))
  }

  /// The cycle in YYYY-mm-dd format.
  public var description: String {
    String(format: "%04d-%02d-%02d", year, month, day)
  }

  public var id: String { description }

  /**
   Generates a cycle from a month, day, and year. Does not validate the cycle.
  
   - Parameter year: The cycle year (2020 or later.
   - Parameter month: The cycle month (1–12).
   - Parameter day: The cycle day (1–31).
   */
  public init(year: UInt, month: UInt8, day: UInt8) {
    self.year = year
    self.month = month
    self.day = day
  }

  /**
   Returns the cycle whose effectivity period includes the given date.
  
   - Parameter date: The date to use.
   - Returns: The cycle covering that date, or `nil` if the date is before the
              ``datum`` date.
   */
  public static func effectiveCycle(for date: Date) -> Self? {
    guard var cycle = datum.date else { return nil }
    guard date >= cycle else { return nil }

    var lastCycle = cycle

    while true {
      if cycle > date {
        return dateToCycle(lastCycle)
      }

      guard let newCycle = calendar.date(byAdding: cycleDuration, to: cycle) else {
        return dateToCycle(cycle)
      }
      lastCycle = cycle
      cycle = newCycle
    }
  }

  private static func dateToCycle(_ date: Date) -> Self? {
    let components = calendar.dateComponents(in: zulu, from: date)
    guard let year = components.year else { return nil }
    guard let mon = components.month else { return nil }
    guard let day = components.day else { return nil }
    return Self(year: UInt(year), month: UInt8(mon), day: UInt8(day))
  }

  /**
   Returns whether a given date falls within this cycle.
  
   - Parameter date: A date to check.
   - Returns: Whether the date falls within the cycle's effectivity period.
   */
  public func contains(_ date: Date) -> Bool {
    guard let dateRange else { return false }
    return dateRange.contains(date)
  }

  enum CodingKeys: String, CodingKey {
    case year, month, day
  }
}
