import Foundation
import Nimble
import Quick

@testable import SwiftNASR

final class DDMMSSByteParsingSpec: QuickSpec {
  override static func spec() {
    // Helper to convert string to bytes
    func bytes(_ string: String) -> ArraySlice<UInt8> {
      Array(string.utf8)[...]
    }

    describe("parseDDMMSS") {
      it("parses north latitude") {
        // 40-25-30.000N = 40 degrees, 25 minutes, 30 seconds North
        // = 40*3600 + 25*60 + 30 = 145530 arc-seconds
        let result = bytes("40-25-30.000N").parseDDMMSS()
        expect(result).to(beCloseTo(145530.0, within: 0.001))
      }

      it("parses south latitude (negative)") {
        // 40-25-30.000S should be negative
        let result = bytes("40-25-30.000S").parseDDMMSS()
        expect(result).to(beCloseTo(-145530.0, within: 0.001))
      }

      it("parses east longitude") {
        // 122-30-45.500E
        // = 122*3600 + 30*60 + 45.5 = 441045.5 arc-seconds
        let result = bytes("122-30-45.500E").parseDDMMSS()
        expect(result).to(beCloseTo(441045.5, within: 0.001))
      }

      it("parses west longitude (negative)") {
        // 122-30-45.500W should be negative
        let result = bytes("122-30-45.500W").parseDDMMSS()
        expect(result).to(beCloseTo(-441045.5, within: 0.001))
      }

      it("handles fractional seconds") {
        // 33-56-53.7900N
        // = 33*3600 + 56*60 + 53.79 = 122213.79 arc-seconds
        let result = bytes("33-56-53.7900N").parseDDMMSS()
        expect(result).to(beCloseTo(122213.79, within: 0.01))
      }

      it("returns nil for invalid format") {
        expect(bytes("invalid").parseDDMMSS()).to(beNil())
        expect(bytes("").parseDDMMSS()).to(beNil())
        expect(bytes("40-25-30.000").parseDDMMSS()).to(beNil())  // missing direction
      }

      it("handles zero values") {
        // 00-00-00.000N
        let result = bytes("00-00-00.000N").parseDDMMSS()
        expect(result).to(beCloseTo(0.0, within: 0.001))
      }
    }
  }
}
