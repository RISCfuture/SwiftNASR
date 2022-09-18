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
                dateComponents.year = 2021
                dateComponents.month = 2
                dateComponents.day = 21

                let cycle = Cycle.effectiveCycle(for: calendar.date(from: dateComponents)!)!

                expect(cycle.year).to(equal(2021))
                expect(cycle.month).to(equal(1))
                expect(cycle.day).to(equal(28))
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
        
        describe("contains") {
            var dateComponents = DateComponents()
            dateComponents.year = 2021
            dateComponents.month = 2
            dateComponents.day = 21

            let cycle = Cycle.effectiveCycle(for: calendar.date(from: dateComponents)!)!
            
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
            var dateComponents = DateComponents()
            dateComponents.year = 2021
            dateComponents.month = 1
            dateComponents.day = 28
            
            let cycle = Cycle.effectiveCycle(for: calendar.date(from: dateComponents)!)!
            
            it("returns the cycle in YYYY-mm-dd format") {
                expect(cycle.description).to(equal("2021-01-28"))
            }
        }
    }
}
