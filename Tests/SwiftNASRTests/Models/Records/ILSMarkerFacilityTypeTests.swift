import Testing

@testable import SwiftNASR

/// Guards the single- and double-letter marker facility-type codes used in CSV
/// distributions (ILS_MKR `MKR_FAC_TYPE_CODE`) against their spelled-out
/// meanings, verified against the ILS layout's facility/type table:
/// `M`→marker, `C`→compass locator, `R`→NDB, `MC`→marker+compass locator,
/// `MR`→marker+NDB.
@Suite
struct ILSMarkerFacilityTypeTests {
  typealias FacilityType = ILS.MarkerBeacon.MarkerFacilityType

  @Test
  func `maps the short CSV codes to the correct facility type`() {
    #expect(FacilityType.for("M") == .marker)
    #expect(FacilityType.for("C") == .compassLocator)
    #expect(FacilityType.for("R") == .NDB)
    #expect(FacilityType.for("MC") == .markerCompassLocator)
    #expect(FacilityType.for("MR") == .markerNDB)
  }

  @Test
  func `still decodes the spelled out TXT values`() {
    #expect(FacilityType.for("MARKER") == .marker)
    #expect(FacilityType.for("COMLO") == .compassLocator)
    #expect(FacilityType.for("MARKER/NDB") == .markerNDB)
  }
}
