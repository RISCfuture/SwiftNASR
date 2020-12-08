import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class StringSpec: QuickSpec {
    override func spec() {
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

