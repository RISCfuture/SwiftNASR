import Foundation
import Nimble
import Quick

@testable import SwiftNASR

final class CycleSpec: QuickSpec {
  override static func spec() {
    let calendar: Calendar = {
      var cal = Calendar(identifier: .iso8601)
      cal.timeZone = TimeZone(secondsFromGMT: 0)!
      return cal
    }()

    describe("effectiveCycle") {
      it("returns the effective cycle for a date") {
        let dateComponents = DateComponents(year: 2021, month: 2, day: 21)
        let cycle = Cycle.effectiveCycle(for: calendar.date(from: dateComponents)!)!

        expect(cycle.year).to(equal(2021))
        expect(cycle.month).to(equal(1))
        expect(cycle.day).to(equal(28))
      }

      it("returns nil if the date comes before the first cycle") {
        let dateComponents = DateComponents(year: 1903, month: 12, day: 17)
        let cycle = Cycle.effectiveCycle(for: calendar.date(from: dateComponents)!)

        expect(cycle).to(beNil())
      }
    }

    describe("contains") {
      var dateComponents: DateComponents! { .init(year: 2021, month: 2, day: 21) }
      var cycle: Cycle { .effectiveCycle(for: calendar.date(from: dateComponents)!)! }

      it("returns true if the date falls within the cycle") {
        let date = Calendar.current.date(from: .init(year: 2021, month: 2, day: 1))!
        expect(cycle.contains(date)).to(beTrue())
      }

      it("returns false if the date does not fall within the cycle") {
        var date = Calendar.current.date(from: .init(year: 2021, month: 2, day: 28))!
        expect(cycle.contains(date)).to(beFalse())

        date = Calendar.current.date(from: .init(year: 2021, month: 1, day: 27))!
        expect(cycle.contains(date)).to(beFalse())
      }
    }

    describe("description") {
      var dateComponents: DateComponents { .init(year: 2021, month: 1, day: 28) }
      var cycle: Cycle { .effectiveCycle(for: calendar.date(from: dateComponents)!)! }

      it("returns the cycle in YYYY-mm-dd format") {
        expect(cycle.description).to(equal("2021-01-28"))
      }
    }

    describe("effective") {
      it("returns the currently effective cycle") {
        let effective = Cycle.effective
        expect(effective.isEffective).to(beTrue())
      }
    }

    describe("cycle(for:)") {
      it("returns the cycle for a given date") {
        let dateComponents = DateComponents(year: 2021, month: 2, day: 21)
        let cycle = Cycle.cycle(for: calendar.date(from: dateComponents)!)

        expect(cycle).toNot(beNil())
        expect(cycle?.year).to(equal(2021))
        expect(cycle?.month).to(equal(1))
        expect(cycle?.day).to(equal(28))
      }

      it("returns nil for dates before datum") {
        let dateComponents = DateComponents(year: 1903, month: 12, day: 17)
        let cycle = Cycle.cycle(for: calendar.date(from: dateComponents)!)

        expect(cycle).to(beNil())
      }
    }

    describe("previous and next") {
      var dateComponents: DateComponents { .init(year: 2021, month: 1, day: 28) }
      var cycle: Cycle { .effectiveCycle(for: calendar.date(from: dateComponents)!)! }

      it("returns the previous cycle") {
        let previous = cycle.previous
        expect(previous).toNot(beNil())
        expect(previous?.year).to(equal(2020))
        expect(previous?.month).to(equal(12))
        expect(previous?.day).to(equal(31))
      }

      it("returns the next cycle") {
        let next = cycle.next
        expect(next).toNot(beNil())
        expect(next?.year).to(equal(2021))
        expect(next?.month).to(equal(2))
        expect(next?.day).to(equal(25))
      }
    }

    describe("Comparable") {
      it("compares cycles correctly") {
        let older = Cycle(year: 2021, month: 1, day: 28)
        let newer = Cycle(year: 2021, month: 2, day: 25)
        let same = Cycle(year: 2021, month: 1, day: 28)

        expect(older < newer).to(beTrue())
        expect(newer > older).to(beTrue())
        expect(older == same).to(beTrue())
      }
    }

    describe("dateRange") {
      var dateComponents: DateComponents { .init(year: 2021, month: 1, day: 28) }
      var cycle: Cycle { .effectiveCycle(for: calendar.date(from: dateComponents)!)! }

      it("returns a date interval covering the cycle") {
        let dateRange = cycle.dateRange
        expect(dateRange).toNot(beNil())

        // Duration should be 28 days
        let expectedDuration: TimeInterval = 28 * 24 * 60 * 60
        expect(dateRange?.duration).to(equal(expectedDuration))
      }
    }

    describe("expirationDate") {
      var dateComponents: DateComponents { .init(year: 2021, month: 1, day: 28) }
      var cycle: Cycle { .effectiveCycle(for: calendar.date(from: dateComponents)!)! }

      it("returns the exact expiration moment") {
        let expirationDate = cycle.expirationDate
        expect(expirationDate).toNot(beNil())

        // expirationDate should equal the next cycle's effectiveDate
        let nextCycle = cycle.next
        expect(expirationDate).to(equal(nextCycle?.effectiveDate))
      }
    }
  }
}
