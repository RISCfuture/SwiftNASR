import Foundation

/**
 NASR data is distributed on a 56-day cycle. The Cycle class represents one such
 time period. Cycles are defined by the first day of their effectivity period.
 */

public struct Cycle: Codable {
    
    /// The year of the first date of the cycle.
    public let year: UInt
    
    /// The month of the first date of the cycle.
    public let month: UInt8
    
    /// The day of the first date of the cycle.
    public let day: UInt8

    private static let calendar = Calendar(identifier: .iso8601)
    
    /// The earliest reference cycle (not necessarily the earliest cycle for
    /// which data is available, but the earliest representable date for a
    /// cycle).
    public static let datum = Cycle(year: 2017, month: 10, day: 12)

    /// `true` if this cycle's effectivity period includes the current date.
    public static var current: Cycle {
        return effectiveCycle(for: Date())!
    }

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
    public var date: Date? {
        return Cycle.calendar.date(from: dateComponents)
    }

    /**
     Returns the cycle whose effectivity period includes the given date.
     
     - Parameter date: The date to use.
     - Returns: The cycle covering that date, or `nil` if the date is before the
                `datum` date.
     */
    public static func effectiveCycle(for date: Date) -> Cycle? {
        guard var cycle = datum.date else { return nil }
        guard date >= cycle else { return nil }

        var lastCycle = cycle

        while (true) {
            if (cycle > date)  {
                return dateToCycle(lastCycle)
            }

            guard let newCycle = calendar.date(byAdding: .day, value: 28, to: cycle) else { return dateToCycle(cycle) }
            lastCycle = cycle
            cycle = newCycle
        }
    }

    private static func dateToCycle(_ date: Date) -> Cycle? {
        let components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date)
        guard let year = components.year else { return nil }
        guard let mon = components.month else { return nil }
        guard let day = components.day else { return nil }
        return Cycle(year: UInt(year), month: UInt8(mon), day: UInt8(day))
    }
    
    enum CodingKeys: String, CodingKey {
        case year, month, day
    }
}
