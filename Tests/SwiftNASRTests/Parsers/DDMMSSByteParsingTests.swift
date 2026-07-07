import Foundation
import Testing

@testable import SwiftNASR

@Suite
struct DDMMSSByteParsingTests {
  private func bytes(_ string: String) -> ArraySlice<UInt8> {
    Array(string.utf8)[...]
  }

  @Test
  func parsesNorthLatitude() throws {
    // 40-25-30.000N = 40 degrees, 25 minutes, 30 seconds North
    // = 40*3600 + 25*60 + 30 = 145530 arc-seconds
    let result = try #require(bytes("40-25-30.000N").parseDDMMSS())
    #expect(abs(result - 145530.0) < 0.001)
  }

  @Test
  func parsesSouthLatitudeNegative() throws {
    // 40-25-30.000S should be negative
    let result = try #require(bytes("40-25-30.000S").parseDDMMSS())
    #expect(abs(result - -145530.0) < 0.001)
  }

  @Test
  func parsesEastLongitude() throws {
    // 122-30-45.500E
    // = 122*3600 + 30*60 + 45.5 = 441045.5 arc-seconds
    let result = try #require(bytes("122-30-45.500E").parseDDMMSS())
    #expect(abs(result - 441045.5) < 0.001)
  }

  @Test
  func parsesWestLongitudeNegative() throws {
    // 122-30-45.500W should be negative
    let result = try #require(bytes("122-30-45.500W").parseDDMMSS())
    #expect(abs(result - -441045.5) < 0.001)
  }

  @Test
  func handlesFractionalSeconds() throws {
    // 33-56-53.7900N
    // = 33*3600 + 56*60 + 53.79 = 122213.79 arc-seconds
    let result = try #require(bytes("33-56-53.7900N").parseDDMMSS())
    #expect(abs(result - 122213.79) < 0.01)
  }

  @Test
  func returnsNilForInvalidFormat() {
    #expect(bytes("invalid").parseDDMMSS() == nil)
    #expect(bytes("").parseDDMMSS() == nil)
    #expect(bytes("40-25-30.000").parseDDMMSS() == nil)  // missing direction
  }

  @Test
  func handlesZeroValues() throws {
    // 00-00-00.000N
    let result = try #require(bytes("00-00-00.000N").parseDDMMSS())
    #expect(abs(result - 0.0) < 0.001)
  }
}
