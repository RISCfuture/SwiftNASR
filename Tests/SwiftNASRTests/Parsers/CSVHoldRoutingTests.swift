import Foundation
import Testing

@testable import SwiftNASR

/// Verifies that the CSV hold parser routes the combined `NAV_TYPE`/`NAV_ID`
/// column to the ILS facility fields when it carries an ILS/MLS facility-type
/// code, and to the navaid fields when it carries a navaid facility type. The
/// TXT format keeps these in separate fields; CSV combines them.
@Suite
struct CSVHoldRoutingTests {
  @Test
  func routesILSTypeCodesToTheILSFieldsAndNavaidTypesToTheNavaidFields() async throws {
    let tempdir = FileManager.default.temporaryDirectory.appendingPathComponent(
      ProcessInfo().globallyUniqueString
    )
    try FileManager.default.createDirectory(at: tempdir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempdir) }

    let header =
      "EFF_DATE,HP_NAME,HP_NO,STATE_CODE,COUNTRY_CODE,FIX_ID,ICAO_REGION_CODE,NAV_ID,NAV_TYPE,"
      + "HOLD_DIRECTION,HOLD_DEG_OR_CRS,AZIMUTH,COURSE_INBOUND_DEG,TURN_DIRECTION,LEG_LENGTH_DIST"
    let base =
      "\(header)\r\n"
      + "2026/05/14,AABEE INT,1,GA,US,AABEE,K7,PDK,LD,NE,26,CRS,206,L,\r\n"
      + "2026/05/14,TESTVOR,1,CA,US,,,ABC,VORTAC,S,165,RNAV,345,R,15\r\n"
    try Data(base.utf8).write(to: tempdir.appendingPathComponent("HPF_BASE.csv"))
    for name in ["HPF_CHRT.csv", "HPF_SPD_ALT.csv", "HPF_RMK.csv"] {
      try Data("HP_NAME,HP_NO\r\n".utf8).write(to: tempdir.appendingPathComponent(name))
    }

    let parser = CSVHoldParser()
    let distribution = DirectoryDistribution(location: tempdir, format: .csv)
    try await parser.prepare(distribution: distribution)
    try await parser.parse(data: Data("CSV".utf8))

    let holds = await parser.holds

    let ilsHold = holds["AABEE INT-1"]
    #expect(ilsHold != nil)
    #expect(ilsHold?.ilsFacilityType == .ILS_DME)
    #expect(ilsHold?.ILSFacilityIdentifier == "PDK")
    #expect(ilsHold?.navaidFacilityType == nil)
    #expect(ilsHold?.navaidIdentifier == nil)

    let navHold = holds["TESTVOR-1"]
    #expect(navHold != nil)
    #expect(navHold?.navaidFacilityType == .VORTAC)
    #expect(navHold?.navaidIdentifier == "ABC")
    #expect(navHold?.ilsFacilityType == nil)
    #expect(navHold?.ILSFacilityIdentifier == nil)
  }

  // The routing above tries `ILSFacilityType` first, so the two facility-type
  // code systems must stay disjoint: a value that decoded as both would be
  // silently routed to the ILS fields. This guards against a future synonym
  // or case that would reintroduce a collision.
  @Test
  func keepsTheILSAndNavaidFacilityTypeCodeSystemsDisjoint() {
    for ilsType in ILSFacilityType.allCases {
      #expect(
        Navaid.FacilityType.for(ilsType.rawValue) == nil,
        "ILS code ‘\(ilsType.rawValue)’ must not also decode as a navaid type"
      )
    }
  }
}
