import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class CycleSpec: QuickSpec {
    override func spec() {
        let calendar = Calendar(identifier: .iso8601)

        describe("effectiveCycle") {
            it("returns the effective cycle for a date") {
                var dateComponents = DateComponents()
                dateComponents.year = 2020
                dateComponents.month = 2
                dateComponents.day = 21

                let cycle = Cycle.effectiveCycle(for: calendar.date(from: dateComponents)!)!

                expect(cycle.year).to(equal(2020))
                expect(cycle.month).to(equal(1))
                expect(cycle.day).to(equal(30))
            }

            it("returns nil if the date comes before the first cycle") {
                var dateComponents = DateComponents()
                dateComponents.year = 1903
                dateComponents.month = 12
                dateComponents.day = 17

                let cycle = Cycle.effectiveCycle(for: calendar.date(from: dateComponents)!)
                expect(cycle).to(beNil())
            }
        }
    }
}
