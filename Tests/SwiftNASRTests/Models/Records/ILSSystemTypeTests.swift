import Testing

@testable import SwiftNASR

/// Guards the two-letter ILS system type codes used in CSV distributions
/// (ILS_* `SYSTEM_TYPE_CODE`, LID `FAC_TYPE`) against the table in the ILS
/// CSV data layout.
@Suite
struct ILSSystemTypeCodeTests {
  static let codes: [(String, ILS.SystemType, LocationIdentifier.ILSFacilityType)] = [
    ("LS", .ILS, .ILS),
    ("SF", .SDF, .SDF),
    ("LC", .localizer, .localizer),
    ("LA", .LDA, .LDA),
    ("LD", .ILS_DME, .ILS_DME),
    ("SD", .SDF_DME, .SDF_DME),
    ("LE", .LOC_DME, .LOC_DME),
    ("LG", .LOC_GS, .LOC_GS),
    ("DD", .LDA_DME, .LDA_DME)
  ]

  @Test(arguments: codes)
  func `maps each CSV code to its system type`(
    code: String,
    systemType: ILS.SystemType,
    facilityType: LocationIdentifier.ILSFacilityType
  ) {
    #expect(ILS.SystemType.for(code) == systemType)
    #expect(LocationIdentifier.ILSFacilityType.for(code) == facilityType)
  }
}
