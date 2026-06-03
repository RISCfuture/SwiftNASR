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

      it("drops separator characters and omits empty tokens at the edges") {
        // The runway-surface parsers rely on this for codes like "ASPH/GRVL".
        let set = CharacterSet(charactersIn: "-/")
        expect("ASPH/GRVL".split(separator: set)).to(equal(["ASPH", "GRVL"]))
        expect("-ASPH".split(separator: set)).to(equal(["ASPH"]))  // leading
        expect("ASPH--CONC".split(separator: set)).to(equal(["ASPH", "CONC"]))  // doubled
        expect("ASPH-".split(separator: set)).to(equal(["ASPH"]))  // trailing
        expect("-".split(separator: set)).to(equal([]))  // separators only
      }
    }
  }
}
