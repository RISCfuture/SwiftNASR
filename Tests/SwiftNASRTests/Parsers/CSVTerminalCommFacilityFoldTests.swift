import Foundation
import Testing

@testable import SwiftNASR

/// Verifies that the CSV terminal-comm-facility parser folds the radar (`RDR.csv`),
/// military-operations (`MIL_OPS.csv`), and class-airspace (`CLS_ARSP.csv`) files —
/// which the FAA split out of the legacy `TWR.txt` — back into the facility records,
/// matching `RDR` by `FACILITY_ID` and `MIL_OPS`/`CLS_ARSP` by `SITE_NO`. Rows that
/// reference an unknown facility/site are surfaced as dropped-row diagnostics rather
/// than aborting the parse.
@Suite
struct CSVTerminalCommFacilityFoldTests {
  @Test
  func foldsRadarMilitaryAndAirspaceDataIntoTheMatchingFacility() async throws {
    let tempdir = FileManager.default.temporaryDirectory.appendingPathComponent(
      ProcessInfo.processInfo.globallyUniqueString
    )
    try FileManager.default.createDirectory(at: tempdir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempdir) }

    func write(_ name: String, _ contents: String) throws {
      try Data(contents.utf8).write(to: tempdir.appendingPathComponent(name))
    }

    // ATC_BASE.csv — one facility (ABQ, SITE_NO 14532.). The header matches the live
    // distribution so the parser's optional-column reads all resolve.
    let atcHeader =
      "EFF_DATE,SITE_NO,SITE_TYPE_CODE,FACILITY_TYPE,STATE_CODE,FACILITY_ID,CITY,COUNTRY_CODE,"
      + "ICAO_ID,FACILITY_NAME,REGION_CODE,TWR_OPERATOR_CODE,TWR_CALL,TWR_HRS,"
      + "PRIMARY_APCH_RADIO_CALL,APCH_P_PROVIDER,APCH_P_PROV_TYPE_CD,SECONDARY_APCH_RADIO_CALL,"
      + "APCH_S_PROVIDER,APCH_S_PROV_TYPE_CD,PRIMARY_DEP_RADIO_CALL,DEP_P_PROVIDER,"
      + "DEP_P_PROV_TYPE_CD,SECONDARY_DEP_RADIO_CALL,DEP_S_PROVIDER,DEP_S_PROV_TYPE_CD,"
      + "CTL_FAC_APCH_DEP_CALLS,APCH_DEP_OPER_CODE,CTL_PRVDING_HRS,SECONDARY_CTL_PRVDING_HRS"
    try write(
      "ATC_BASE.csv",
      "\(atcHeader)\r\n"
        + "2026/05/14,14532.,A,ATCT-TRACON,NM,ABQ,ALBUQUERQUE,US,KABQ,ALBUQUERQUE INTL SUNPORT,"
        + "ASW,F,ALBUQUERQUE,24,ALBUQUERQUE,ABQ,A,,,,ALBUQUERQUE,ABQ,A,,,,ALBUQUERQUE,F,24,\r\n"
    )

    // The remaining ATC_* files are required by the parser but irrelevant here.
    try write("ATC_SVC.csv", "FACILITY_ID,CTL_SVC\r\n")
    try write("ATC_ATIS.csv", "FACILITY_ID,ATIS_NO\r\n")
    try write("ATC_RMK.csv", "FACILITY_ID,REMARK\r\n")

    // RDR.csv — two radars for ABQ (ASR then BCN, proving multiple free-form
    // equipment entries in order) and one row for an unknown facility.
    try write(
      "RDR.csv",
      "EFF_DATE,FACILITY_ID,FACILITY_TYPE,STATE_CODE,COUNTRY_CODE,RADAR_TYPE,RADAR_NO,RADAR_HRS,"
        + "REMARK\r\n"
        + "2026/05/14,ABQ,AIRPORT,NM,US,ASR,1,24,\r\n"
        + "2026/05/14,ABQ,AIRPORT,NM,US,BCN,2,24,\r\n"
        + "2026/05/14,ZZZZ,AIRPORT,NM,US,ASR,1,24,\r\n"
    )

    // MIL_OPS.csv — matched row for ABQ (operator code A → U.S. AIR FORCE) and one
    // row for an unknown site number.
    try write(
      "MIL_OPS.csv",
      "EFF_DATE,SITE_NO,SITE_TYPE_CODE,STATE_CODE,ARPT_ID,CITY,COUNTRY_CODE,MIL_OPS_OPER_CODE,"
        + "MIL_OPS_CALL,MIL_OPS_HRS,AMCP_HRS,PMSV_HRS,REMARK\r\n"
        + "2026/05/14,14532.,A,NM,ABQ,ALBUQUERQUE,US,A,TACO,0600-2200 MON-FRI,24,18,\r\n"
        + "2026/05/14,99999.,A,NM,XXX,NOWHERE,US,R,,,,,\r\n"
    )

    // CLS_ARSP.csv — matched row for ABQ with Class C airspace.
    try write(
      "CLS_ARSP.csv",
      "EFF_DATE,SITE_NO,SITE_TYPE_CODE,STATE_CODE,ARPT_ID,CITY,COUNTRY_CODE,CLASS_B_AIRSPACE,"
        + "CLASS_C_AIRSPACE,CLASS_D_AIRSPACE,CLASS_E_AIRSPACE,AIRSPACE_HRS,REMARK\r\n"
        + "2026/05/14,14532.,A,NM,ABQ,ALBUQUERQUE,US,,Y,,,,\r\n"
    )

    let parser = CSVTerminalCommFacilityParser()
    let distribution = DirectoryDistribution(location: tempdir, format: .csv)
    try await parser.prepare(distribution: distribution)
    try await parser.parse(data: Data("CSV".utf8))

    let facility = await parser.facilities["ABQ"]
    #expect(facility != nil)

    // Radar (RDR.csv) — two equipment entries in file order, free-form type strings.
    #expect(facility?.radar != nil)
    #expect(facility?.radar?.equipment.count == 2)
    #expect(facility?.radar?.equipment.map(\.radarType) == ["ASR", "BCN"])
    #expect(facility?.radar?.equipment.first?.hours == "24")

    // Military operations (MIL_OPS.csv) — code decoded to the TXT agency name.
    #expect(facility?.militaryOperator == "U.S. AIR FORCE")
    #expect(facility?.militaryRadioCall == "TACO")
    #expect(facility?.militaryOperationsHours == "0600-2200 MON-FRI")
    #expect(facility?.macpHours == "24")
    #expect(facility?.pmsvHours == "18")

    // Class airspace (CLS_ARSP.csv) — Y/blank flags.
    #expect(facility?.airspace != nil)
    #expect(facility?.airspace?.classC == true)
    #expect(facility?.airspace?.classB == false)
    #expect(facility?.airspace?.classD == false)
    #expect(facility?.airspace?.classE == false)

    // The unknown-facility RDR row and unknown-site MIL_OPS row are dropped with
    // diagnostics, not aborted.
    let diagnostics = await parser.takeDiagnostics()
    #expect(diagnostics.count == 2)
  }
}
