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
  func returnsTheEffectiveCycleForADate() {
    let cycle = Cycle.effectiveCycle(
      for: calendar.date(from: .init(year: 2021, month: 2, day: 21))!
    )!
    #expect(cycle.year == 2021)
    #expect(cycle.month == 1)
    #expect(cycle.day == 28)
  }

  @Test
  func returnsNilIfTheDateComesBeforeTheFirstCycle() {
    let cycle = Cycle.effectiveCycle(
      for: calendar.date(from: .init(year: 1903, month: 12, day: 17))!
    )
    #expect(cycle == nil)
  }

  // MARK: contains

  @Test
  func returnsTrueIfTheDateFallsWithinTheCycle() {
    let cycle = cycle(year: 2021, month: 2, day: 21)
    let date = Calendar.current.date(from: .init(year: 2021, month: 2, day: 1))!
    #expect(cycle.contains(date))
  }

  @Test
  func returnsFalseIfTheDateDoesNotFallWithinTheCycle() {
    let cycle = cycle(year: 2021, month: 2, day: 21)
    var date = Calendar.current.date(from: .init(year: 2021, month: 2, day: 28))!
    #expect(!cycle.contains(date))

    date = Calendar.current.date(from: .init(year: 2021, month: 1, day: 27))!
    #expect(!cycle.contains(date))
  }

  // MARK: description

  @Test
  func returnsTheCycleInYYYYmmddFormat() {
    #expect(cycle(year: 2021, month: 1, day: 28).description == "2021-01-28")
  }

  // MARK: effective

  @Test
  func returnsTheCurrentlyEffectiveCycle() {
    #expect(Cycle.effective.isEffective)
  }

  // MARK: cycle(for:)

  @Test
  func returnsTheCycleForAGivenDate() {
    let cycle = Cycle.cycle(for: calendar.date(from: .init(year: 2021, month: 2, day: 21))!)
    #expect(cycle != nil)
    #expect(cycle?.year == 2021)
    #expect(cycle?.month == 1)
    #expect(cycle?.day == 28)
  }

  @Test
  func returnsNilForDatesBeforeDatum() {
    let cycle = Cycle.cycle(for: calendar.date(from: .init(year: 1903, month: 12, day: 17))!)
    #expect(cycle == nil)
  }

  // MARK: previous and next

  @Test
  func returnsThePreviousCycle() {
    let previous = cycle(year: 2021, month: 1, day: 28).previous
    #expect(previous != nil)
    #expect(previous?.year == 2020)
    #expect(previous?.month == 12)
    #expect(previous?.day == 31)
  }

  @Test
  func returnsTheNextCycle() {
    let next = cycle(year: 2021, month: 1, day: 28).next
    #expect(next != nil)
    #expect(next?.year == 2021)
    #expect(next?.month == 2)
    #expect(next?.day == 25)
  }

  // MARK: Comparable

  @Test
  func comparesCyclesCorrectly() {
    let older = Cycle(year: 2021, month: 1, day: 28)
    let newer = Cycle(year: 2021, month: 2, day: 25)
    let same = Cycle(year: 2021, month: 1, day: 28)

    #expect(older < newer)
    #expect(newer > older)
    #expect(older == same)
  }

  // MARK: dateRange

  @Test
  func returnsADateIntervalCoveringTheCycle() {
    let dateRange = cycle(year: 2021, month: 1, day: 28).dateRange
    #expect(dateRange != nil)

    // Duration should be 28 days
    let expectedDuration: TimeInterval = 28 * 24 * 60 * 60
    #expect(dateRange?.duration == expectedDuration)
  }

  // MARK: expirationDate

  @Test
  func returnsTheExactExpirationMoment() {
    let cycle = cycle(year: 2021, month: 1, day: 28)
    let expirationDate = cycle.expirationDate
    #expect(expirationDate != nil)

    // expirationDate should equal the next cycle's effectiveDate
    #expect(expirationDate == cycle.next?.effectiveDate)
  }
}
