import Foundation
import Nimble
import Quick

@testable import SwiftNASR

final class CycleSpec: QuickSpec {
    override static func spec() {
        let calendar = Calendar(identifier: .iso8601)

        describe("effectiveCycle") {
            it("returns the effective cycle for a date") {
                var dateComponents = DateComponents(year: 2021, month: 2, day: 21)
                let cycle = Cycle.effectiveCycle(for: calendar.date(from: dateComponents)!)!

                expect(cycle.year).to(equal(2021))
                expect(cycle.month).to(equal(1))
                expect(cycle.day).to(equal(28))
            }

            it("returns nil if the date comes before the first cycle") {
                var dateComponents = DateComponents(year: 1903, month: 12, day: 17)
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
            var dateComponents: DateComponents {.init(year: 2021, month: 1, day: 28) }
            var cycle: Cycle { .effectiveCycle(for: calendar.date(from: dateComponents)!)! }

            it("returns the cycle in YYYY-mm-dd format") {
                expect(cycle.description).to(equal("2021-01-28"))
            }
        }
    }
}
