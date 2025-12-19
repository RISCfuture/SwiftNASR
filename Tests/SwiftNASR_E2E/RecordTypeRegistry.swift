import SwiftNASR

/// Metadata about a record type including display name and parsing weights.
struct RecordTypeInfo {
  let recordType: RecordType
  let displayName: String
  let txtWeight: Int64?  // nil if not available in TXT
  let csvWeight: Int64?  // nil if not available in CSV

  var availableInTXT: Bool { txtWeight != nil }
  var availableInCSV: Bool { csvWeight != nil }

  func weight(isCSV: Bool) -> Int64 {
    (isCSV ? csvWeight : txtWeight) ?? 1
  }
}

/// Central registry of all record types with their metadata.
/// Weights are approximate record counts (TXT) or file sizes in MB (CSV).
let recordTypeRegistry: [RecordType: RecordTypeInfo] = [
  .airports: RecordTypeInfo(
    recordType: .airports,
    displayName: "Airports",
    txtWeight: 153,  // APT.txt: ~153k lines
    csvWeight: 55  // APT_*.csv + FRQ.csv: ~55MB total
  ),
  .ARTCCFacilities: RecordTypeInfo(
    recordType: .ARTCCFacilities,
    displayName: "ARTCCs",
    txtWeight: 7,  // AFF.txt: ~7k lines
    csvWeight: 1  // ATC_*.csv: ~1MB total
  ),
  .flightServiceStations: RecordTypeInfo(
    recordType: .flightServiceStations,
    displayName: "FSSes",
    txtWeight: 1,  // FSS.txt: ~100 lines
    csvWeight: 1  // FSS_BASE.csv: negligible
  ),
  .navaids: RecordTypeInfo(
    recordType: .navaids,
    displayName: "Navaids",
    txtWeight: 8,  // NAV.txt: ~8k lines
    csvWeight: 1  // NAV_BASE.csv: ~1MB
  ),
  .reportingPoints: RecordTypeInfo(
    recordType: .reportingPoints,
    displayName: "Fixes",
    txtWeight: 202,  // FIX.txt: ~202k lines
    csvWeight: 17  // FIX_*.csv: ~17MB total
  ),
  .weatherReportingStations: RecordTypeInfo(
    recordType: .weatherReportingStations,
    displayName: "Weather Stations",
    txtWeight: 3,  // AWOS.txt: ~3k lines
    csvWeight: 1  // AWOS.csv: ~0.5MB
  ),
  .airways: RecordTypeInfo(
    recordType: .airways,
    displayName: "Airways",
    txtWeight: 37,  // AWY.txt: ~37k lines
    csvWeight: 4  // AWY_*.csv: ~4MB total
  ),
  .ILSes: RecordTypeInfo(
    recordType: .ILSes,
    displayName: "ILS Facilities",
    txtWeight: 11,  // ILS.txt: ~11k lines
    csvWeight: 1  // ILS_*.csv: ~0.5MB
  ),
  .terminalCommFacilities: RecordTypeInfo(
    recordType: .terminalCommFacilities,
    displayName: "Terminal Comm Facilities",
    txtWeight: 26,  // TWR.txt: ~26k lines
    csvWeight: 8  // FRQ.csv: ~8MB
  ),
  .departureArrivalProceduresComplete: RecordTypeInfo(
    recordType: .departureArrivalProceduresComplete,
    displayName: "Departure/Arrival Procedures Complete",
    txtWeight: 37,  // STARDP.txt: ~37k lines
    csvWeight: nil  // Not available in CSV
  ),
  .preferredRoutes: RecordTypeInfo(
    recordType: .preferredRoutes,
    displayName: "Preferred Routes",
    txtWeight: 87,  // PFR.txt: ~87k lines
    csvWeight: nil  // Not available in CSV
  ),
  .holds: RecordTypeInfo(
    recordType: .holds,
    displayName: "Holds",
    txtWeight: 45,  // HPF.txt: ~45k lines
    csvWeight: nil  // Not available in CSV
  ),
  .weatherReportingLocations: RecordTypeInfo(
    recordType: .weatherReportingLocations,
    displayName: "Weather Reporting Locations",
    txtWeight: 3,  // WXL.txt: ~3k lines
    csvWeight: nil  // Not available in CSV
  ),
  .parachuteJumpAreas: RecordTypeInfo(
    recordType: .parachuteJumpAreas,
    displayName: "Parachute Jump Areas",
    txtWeight: 2,  // PJA.txt: ~2k lines
    csvWeight: 1  // PJA_*.csv: ~0.2MB total
  ),
  .militaryTrainingRoutes: RecordTypeInfo(
    recordType: .militaryTrainingRoutes,
    displayName: "Military Training Routes",
    txtWeight: 31,  // MTR.txt: ~31k lines
    csvWeight: nil  // Not available in CSV
  ),
  .codedDepartureRoutes: RecordTypeInfo(
    recordType: .codedDepartureRoutes,
    displayName: "Coded Departure Routes",
    txtWeight: nil,  // Not available in TXT
    csvWeight: 5  // CDR.csv: ~5MB
  ),
  .miscActivityAreas: RecordTypeInfo(
    recordType: .miscActivityAreas,
    displayName: "Misc Activity Areas",
    txtWeight: 1,  // MAA.txt: ~1k lines
    csvWeight: nil  // Not available in CSV
  ),
  .ARTCCBoundarySegments: RecordTypeInfo(
    recordType: .ARTCCBoundarySegments,
    displayName: "ARTCC Boundary Segments",
    txtWeight: 3,  // ARB.txt: ~3k lines
    csvWeight: nil  // Not available in CSV
  ),
  .FSSCommFacilities: RecordTypeInfo(
    recordType: .FSSCommFacilities,
    displayName: "FSS Comm Facilities",
    txtWeight: 1,  // COM.txt: ~1k lines
    csvWeight: nil  // Not available in CSV
  ),
  .ATSAirways: RecordTypeInfo(
    recordType: .ATSAirways,
    displayName: "ATS Airways",
    txtWeight: 4,  // ATS.txt: ~4k lines
    csvWeight: nil  // Not available in CSV
  ),
  .locationIdentifiers: RecordTypeInfo(
    recordType: .locationIdentifiers,
    displayName: "Location Identifiers",
    txtWeight: 23,  // LID.txt: ~23k lines
    csvWeight: 2  // LID.csv: ~2MB
  )
]

// MARK: - NASRData Accessors

/// Returns the count of records for a given record type from NASRData.
/// This handles the naming mismatch between RecordType and NASRData properties.
func getRecordCount(from data: NASRData, for recordType: RecordType) async -> Int? {
  switch recordType {
    case .airports: return await data.airports?.count
    case .ARTCCFacilities: return await data.ARTCCs?.count
    case .flightServiceStations: return await data.FSSes?.count
    case .navaids: return await data.navaids?.count
    case .reportingPoints: return await data.fixes?.count
    case .weatherReportingStations: return await data.weatherStations?.count
    case .airways: return await data.airways?.count
    case .ILSes: return await data.ILSFacilities?.count
    case .terminalCommFacilities: return await data.terminalCommFacilities?.count
    case .departureArrivalProceduresComplete:
      return await data.departureArrivalProceduresComplete?.count
    case .preferredRoutes: return await data.preferredRoutes?.count
    case .holds: return await data.holds?.count
    case .weatherReportingLocations: return await data.weatherReportingLocations?.count
    case .parachuteJumpAreas: return await data.parachuteJumpAreas?.count
    case .militaryTrainingRoutes: return await data.militaryTrainingRoutes?.count
    case .codedDepartureRoutes: return await data.codedDepartureRoutes?.count
    case .miscActivityAreas: return await data.miscActivityAreas?.count
    case .ARTCCBoundarySegments: return await data.ARTCCBoundarySegments?.count
    case .FSSCommFacilities: return await data.FSSCommFacilities?.count
    case .ATSAirways: return await data.atsAirways?.count
    case .locationIdentifiers: return await data.locationIdentifiers?.count
    case .states: return await data.states?.count
  }
}

/// Checks if the record data is nil for a given record type.
func isRecordNil(in data: NASRData, for recordType: RecordType) async -> Bool {
  switch recordType {
    case .airports: return await data.airports == nil
    case .ARTCCFacilities: return await data.ARTCCs == nil
    case .flightServiceStations: return await data.FSSes == nil
    case .navaids: return await data.navaids == nil
    case .reportingPoints: return await data.fixes == nil
    case .weatherReportingStations: return await data.weatherStations == nil
    case .airways: return await data.airways == nil
    case .ILSes: return await data.ILSFacilities == nil
    case .terminalCommFacilities: return await data.terminalCommFacilities == nil
    case .departureArrivalProceduresComplete:
      return await data.departureArrivalProceduresComplete == nil
    case .preferredRoutes: return await data.preferredRoutes == nil
    case .holds: return await data.holds == nil
    case .weatherReportingLocations: return await data.weatherReportingLocations == nil
    case .parachuteJumpAreas: return await data.parachuteJumpAreas == nil
    case .militaryTrainingRoutes: return await data.militaryTrainingRoutes == nil
    case .codedDepartureRoutes: return await data.codedDepartureRoutes == nil
    case .miscActivityAreas: return await data.miscActivityAreas == nil
    case .ARTCCBoundarySegments: return await data.ARTCCBoundarySegments == nil
    case .FSSCommFacilities: return await data.FSSCommFacilities == nil
    case .ATSAirways: return await data.atsAirways == nil
    case .locationIdentifiers: return await data.locationIdentifiers == nil
    case .states: return await data.states == nil
  }
}

/// List of all record types (excluding states which is special-cased).
let allRecordTypes: [RecordType] = [
  .airports, .ARTCCFacilities, .ARTCCBoundarySegments, .ATSAirways,
  .airways, .codedDepartureRoutes, .departureArrivalProceduresComplete,
  .flightServiceStations, .FSSCommFacilities, .holds, .ILSes,
  .locationIdentifiers, .militaryTrainingRoutes, .miscActivityAreas,
  .navaids, .parachuteJumpAreas, .preferredRoutes, .reportingPoints,
  .terminalCommFacilities, .weatherReportingLocations, .weatherReportingStations
]
