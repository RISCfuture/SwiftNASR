import Foundation
import Testing

@testable import SwiftNASR

@Suite
struct CycleTests {
  private let calendar: Calendar = {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(secondsFromGMT: 0)!
    return cal
  }()

  private func cycle(year: Int, month: Int, day: Int) -> Cycle {
    Cycle.effectiveCycle(for: calendar.date(from: .init(year: year, month: month, day: day))!)!
  }

  // MARK: effectiveCycle

  @Test
  func `returns the effective cycle for a date`() {
    let cycle = Cycle.effectiveCycle(
      for: calendar.date(from: .init(year: 2021, month: 2, day: 21))!
    )!
    #expect(cycle.year == 2021)
    #expect(cycle.month == 1)
    #expect(cycle.day == 28)
  }

  @Test
  func `returns nil if the date comes before the first cycle`() {
    let cycle = Cycle.effectiveCycle(
      for: calendar.date(from: .init(year: 1903, month: 12, day: 17))!
    )
    #expect(cycle == nil)
  }

  // MARK: contains

  @Test
  func `returns true if the date falls within the cycle`() {
    let cycle = cycle(year: 2021, month: 2, day: 21)
    let date = Calendar.current.date(from: .init(year: 2021, month: 2, day: 1))!
    #expect(cycle.contains(date))
  }

  @Test
  func `returns false if the date does not fall within the cycle`() {
    let cycle = cycle(year: 2021, month: 2, day: 21)
    var date = Calendar.current.date(from: .init(year: 2021, month: 2, day: 28))!
    #expect(!cycle.contains(date))

    date = Calendar.current.date(from: .init(year: 2021, month: 1, day: 27))!
    #expect(!cycle.contains(date))
  }

  // MARK: description

  @Test
  func `returns the cycle in YYYY-MM-DD format`() {
    #expect(cycle(year: 2021, month: 1, day: 28).description == "2021-01-28")
  }

  // MARK: effective

  @Test
  func `returns the currently effective cycle`() {
    #expect(Cycle.effective.isEffective)
  }

  // MARK: cycle(for:)

  @Test
  func `returns the cycle for a given date`() {
    let cycle = Cycle.cycle(for: calendar.date(from: .init(year: 2021, month: 2, day: 21))!)
    #expect(cycle != nil)
    #expect(cycle?.year == 2021)
    #expect(cycle?.month == 1)
    #expect(cycle?.day == 28)
  }

  @Test
  func `returns nil for dates before datum`() {
    let cycle = Cycle.cycle(for: calendar.date(from: .init(year: 1903, month: 12, day: 17))!)
    #expect(cycle == nil)
  }

  // MARK: previous and next

  @Test
  func `returns the previous cycle`() {
    let previous = cycle(year: 2021, month: 1, day: 28).previous
    #expect(previous != nil)
    #expect(previous?.year == 2020)
    #expect(previous?.month == 12)
    #expect(previous?.day == 31)
  }

  @Test
  func `returns the next cycle`() {
    let next = cycle(year: 2021, month: 1, day: 28).next
    #expect(next != nil)
    #expect(next?.year == 2021)
    #expect(next?.month == 2)
    #expect(next?.day == 25)
  }

  // MARK: Comparable

  @Test
  func `compares cycles correctly`() {
    let older = Cycle(year: 2021, month: 1, day: 28)
    let newer = Cycle(year: 2021, month: 2, day: 25)
    let same = Cycle(year: 2021, month: 1, day: 28)

    #expect(older < newer)
    #expect(newer > older)
    #expect(older == same)
  }

  // MARK: dateRange

  @Test
  func `returns a date interval covering the cycle`() {
    let dateRange = cycle(year: 2021, month: 1, day: 28).dateRange
    #expect(dateRange != nil)

    // Duration should be 28 days
    let expectedDuration: TimeInterval = 28 * 24 * 60 * 60
    #expect(dateRange?.duration == expectedDuration)
  }

  // MARK: expirationDate

  @Test
  func `returns the exact expiration moment`() {
    let cycle = cycle(year: 2021, month: 1, day: 28)
    let expirationDate = cycle.expirationDate
    #expect(expirationDate != nil)

    // expirationDate should equal the next cycle's effectiveDate
    #expect(expirationDate == cycle.next?.effectiveDate)
  }

  // MARK: parseReadmeCycleDate

  @Test(arguments: [
    "October 32, 2025",  // day out of range for the month
    "February 30, 2025",
    "October 30, 2025 and more words",  // trailing text
    "October 30, 2025extra",
    "Octobre 30, 2025",  // not the README's locale
    "10/30/2025",  // not the README's format
    ""
  ])
  func `rejects a malformed README effective date`(_ input: String) {
    #expect(parseReadmeCycleDate(input) == nil)
  }

  @Test(arguments: [
    ("October 30, 2025", 2025, 10, 30),
    ("January 1, 2026", 2026, 1, 1),
    ("December 31, 2025", 2025, 12, 31),
    ("  March 5, 2024  ", 2024, 3, 5),  // surrounding whitespace is tolerated
    ("September 03, 2026", 2026, 9, 3),  // the distributions pad the day
    ("October 01, 2026.", 2026, 10, 1)  // and end the sentence
  ])
  func `parses a well-formed README effective date`(
    _ input: String,
    _ year: Int,
    _ month: Int,
    _ day: Int
  ) throws {
    let date = try #require(parseReadmeCycleDate(input))
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    #expect(components.year == year)
    #expect(components.month == month)
    #expect(components.day == day)
  }
}
