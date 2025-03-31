import Foundation
import Nimble
import Quick

@testable import SwiftNASR

enum TestEnum: String, RecordEnum {
    case first = "1"
    case second = "2"

    static let synonyms: [RawValue: Self] = [
        "ONE": .first,
        "TWO": .second
    ]
}

final class RecordEnumSpec: QuickSpec {
    override static func spec() {
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
