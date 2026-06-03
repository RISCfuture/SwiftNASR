import Nimble
import Quick

@testable import SwiftNASR

/// Guards the single-character back-course status codes used in CSV
/// distributions against the spelled-out meanings, which were verified
/// per-record against the live ILS distribution (`N` = "NO RESTRICTIONS",
/// `U` = "UNUSABLE", `Y` = "USABLE", `R` = "RESTRICTED").
final class ILSBackCourseStatusSpec: QuickSpec {
  override static func spec() {
    it("maps single-character CSV codes to the correct spelled-out status") {
      expect(ILS.BackCourseStatus.for("Y")).to(equal(.usable))
      expect(ILS.BackCourseStatus.for("U")).to(equal(.unusable))
      expect(ILS.BackCourseStatus.for("N")).to(equal(.noRestrictions))
      expect(ILS.BackCourseStatus.for("R")).to(equal(.restricted))
    }
  }
}
