import Foundation
import Nimble
import Quick

@testable import SwiftNASR

final class StringSpec: QuickSpec {
    override static func spec() {
        describe("partition") {
            it("partitions by length") {
                let partitions = "abc123def".partition(by: 3)
                expect(partitions).to(equal(["abc", "123", "def"]))
            }
        }

        describe("split") {
            it("splits on a CharacterSet") {
                let components = "abc 123\na".split(separator: .whitespacesAndNewlines)
                expect(components).to(equal(["abc", "123", "a"]))
            }
        }
    }
}
