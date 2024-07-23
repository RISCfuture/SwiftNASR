import Foundation
import Quick
import Nimble

@testable import SwiftNASR

enum TestEnum: String, RecordEnum {
    case first = "1"
    case second = "2"
    
    static var synonyms: Dictionary<RawValue, TestEnum> = [
        "ONE": .first,
        "TWO": .second
    ]
}

class RecordEnumSpec: QuickSpec {
    override class func spec() {
        describe("for") {
            it("returns an enum value by raw value") {
                let value = TestEnum.for("1")
                switch value! {
                    case .first: _ = succeed()
                    case .second: fail("Expected TestEnum.first, got .second")
                }
            }
            
            it("returns an enum value by synonym") {
                let value = TestEnum.for("ONE")
                switch value! {
                    case .first: _ = succeed()
                    case .second: fail("Expected TestEnum.first, got .second")
                }
            }
            
            it("returns nil for unknown values") {
                let value = TestEnum.for("3")
                expect(value).to(beNil())
            }
        }
    }
}
