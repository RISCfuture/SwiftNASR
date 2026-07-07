import Testing

@testable import SwiftNASR

/// Guards the single-character back-course status codes used in CSV
/// distributions against the spelled-out meanings, which were verified
/// per-record against the live ILS distribution (`N` = "NO RESTRICTIONS",
/// `U` = "UNUSABLE", `Y` = "USABLE", `R` = "RESTRICTED").
@Suite
struct ILSBackCourseStatusTests {
  @Test
  func mapsSingleCharacterCSVCodesToTheCorrectSpelledOutStatus() {
    #expect(ILS.BackCourseStatus.for("Y") == .usable)
    #expect(ILS.BackCourseStatus.for("U") == .unusable)
    #expect(ILS.BackCourseStatus.for("N") == .noRestrictions)
    #expect(ILS.BackCourseStatus.for("R") == .restricted)
  }
}
