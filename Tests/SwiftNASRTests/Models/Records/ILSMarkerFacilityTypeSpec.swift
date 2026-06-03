import Nimble
import Quick

@testable import SwiftNASR

/// Guards the single- and double-letter marker facility-type codes used in CSV
/// distributions (ILS_MKR `MKR_FAC_TYPE_CODE`) against their spelled-out
/// meanings, verified against the ILS layout's facility/type table:
/// `M`→marker, `C`→compass locator, `R`→NDB, `MC`→marker+compass locator,
/// `MR`→marker+NDB.
final class ILSMarkerFacilityTypeSpec: QuickSpec {
  override static func spec() {
    it("maps the short CSV codes to the correct facility type") {
      typealias FacilityType = ILS.MarkerBeacon.MarkerFacilityType
      expect(FacilityType.for("M")).to(equal(.marker))
      expect(FacilityType.for("C")).to(equal(.compassLocator))
      expect(FacilityType.for("R")).to(equal(.NDB))
      expect(FacilityType.for("MC")).to(equal(.markerCompassLocator))
      expect(FacilityType.for("MR")).to(equal(.markerNDB))
    }

    it("still decodes the spelled-out TXT values") {
      typealias FacilityType = ILS.MarkerBeacon.MarkerFacilityType
      expect(FacilityType.for("MARKER")).to(equal(.marker))
      expect(FacilityType.for("COMLO")).to(equal(.compassLocator))
      expect(FacilityType.for("MARKER/NDB")).to(equal(.markerNDB))
    }
  }
}
