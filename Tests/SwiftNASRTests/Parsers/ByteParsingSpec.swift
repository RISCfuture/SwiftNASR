import Foundation
import Nimble
import Quick

@testable import SwiftNASR

final class ByteParsingSpec: QuickSpec {
  override static func spec() {
    // Helper to convert string to bytes
    func bytes(_ string: String) -> ArraySlice<UInt8> {
      Array(string.utf8)[...]
    }

    describe("isBlank") {
      it("returns true for empty") {
        expect(bytes("").isBlank()).to(beTrue())
      }

      it("returns true for spaces only") {
        expect(bytes("   ").isBlank()).to(beTrue())
      }

      it("returns true for tabs only") {
        expect(bytes("\t\t").isBlank()).to(beTrue())
      }

      it("returns true for mixed whitespace") {
        expect(bytes(" \t ").isBlank()).to(beTrue())
      }

      it("returns false for non-whitespace") {
        expect(bytes("abc").isBlank()).to(beFalse())
        expect(bytes(" abc ").isBlank()).to(beFalse())
      }
    }

    describe("trimmed") {
      it("removes leading spaces") {
        expect(bytes("   abc").toTrimmedString()).to(equal("abc"))
      }

      it("removes trailing spaces") {
        expect(bytes("abc   ").toTrimmedString()).to(equal("abc"))
      }

      it("removes leading and trailing spaces") {
        expect(bytes("   abc   ").toTrimmedString()).to(equal("abc"))
      }

      it("removes tabs") {
        expect(bytes("\tabc\t").toTrimmedString()).to(equal("abc"))
      }

      it("removes mixed whitespace") {
        expect(bytes(" \t abc \t ").toTrimmedString()).to(equal("abc"))
      }

      it("handles empty string") {
        expect(bytes("").toTrimmedString()).to(equal(""))
      }

      it("handles whitespace only") {
        expect(bytes("   ").toTrimmedString()).to(equal(""))
      }
    }

    describe("parseInt") {
      it("parses positive integers") {
        expect(bytes("123").parseInt()).to(equal(123))
      }

      it("parses negative integers") {
        expect(bytes("-456").parseInt()).to(equal(-456))
      }

      it("parses with leading plus") {
        expect(bytes("+789").parseInt()).to(equal(789))
      }

      it("trims whitespace") {
        expect(bytes("  123  ").parseInt()).to(equal(123))
      }

      it("returns nil for empty") {
        expect(bytes("").parseInt()).to(beNil())
      }

      it("returns nil for whitespace only") {
        expect(bytes("   ").parseInt()).to(beNil())
      }

      it("returns nil for non-numeric") {
        expect(bytes("abc").parseInt()).to(beNil())
      }

      it("returns nil for mixed content") {
        expect(bytes("12a").parseInt()).to(beNil())
      }
    }

    describe("parseUInt") {
      it("parses unsigned integers") {
        expect(bytes("123").parseUInt()).to(equal(123))
      }

      it("parses with leading plus") {
        expect(bytes("+789").parseUInt()).to(equal(789))
      }

      it("trims whitespace") {
        expect(bytes("  456  ").parseUInt()).to(equal(456))
      }

      it("returns nil for negative") {
        expect(bytes("-123").parseUInt()).to(beNil())
      }
    }

    describe("parseFloat") {
      it("parses floats") {
        expect(bytes("123.45").parseFloat()).to(beCloseTo(123.45, within: 0.001))
      }

      it("parses negative floats") {
        expect(bytes("-123.45").parseFloat()).to(beCloseTo(-123.45, within: 0.001))
      }

      it("trims whitespace") {
        expect(bytes("  1.5  ").parseFloat()).to(beCloseTo(1.5, within: 0.001))
      }

      it("returns nil for empty") {
        expect(bytes("").parseFloat()).to(beNil())
      }
    }

    describe("parseFrequencyKHz") {
      it("parses MHz.kHz format") {
        expect(bytes("118.125").parseFrequencyKHz()).to(equal(118125))
      }

      it("parses MHz.k format with padding") {
        expect(bytes("118.1").parseFrequencyKHz()).to(equal(118100))
      }

      it("parses MHz only format") {
        expect(bytes("365").parseFrequencyKHz()).to(equal(365000))
      }

      it("trims whitespace") {
        expect(bytes("  118.5  ").parseFrequencyKHz()).to(equal(118500))
      }

      it("returns nil for invalid format") {
        expect(bytes("abc").parseFrequencyKHz()).to(beNil())
      }
    }

    describe("matches") {
      it("returns true for exact match") {
        expect(bytes("ABC").matches("ABC")).to(beTrue())
      }

      it("returns false for different content") {
        expect(bytes("ABC").matches("DEF")).to(beFalse())
      }

      it("returns false for different length") {
        expect(bytes("ABC").matches("AB")).to(beFalse())
        expect(bytes("AB").matches("ABC")).to(beFalse())
      }
    }

    describe("trimmedMatches") {
      it("matches after trimming") {
        expect(bytes("  ABC  ").trimmedMatches("ABC")).to(beTrue())
      }

      it("does not match untrimmed content") {
        expect(bytes("  ABC  ").matches("ABC")).to(beFalse())
      }
    }

    describe("toString") {
      it("converts bytes to string") {
        expect(bytes("Hello").toString()).to(equal("Hello"))
      }

      it("returns empty string for empty bytes") {
        expect(bytes("").toString()).to(equal(""))
      }
    }
  }
}
