import SwiftNASR

/// Approximate record counts from live FAA distribution data (in thousands, minimum 1).
/// These weights ensure progress bars advance proportionally to parsing work.
let txtRecordWeights: [RecordType: Int64] = [
  .reportingPoints: 202,  // FIX.txt: ~202k lines
  .airports: 153,  // APT.txt: ~153k lines
  .preferredRoutes: 87,  // PFR.txt: ~87k lines
  .holds: 45,  // HPF.txt: ~45k lines
  .departureArrivalProceduresComplete: 37,  // STARDP.txt: ~37k lines
  .airways: 37,  // AWY.txt: ~37k lines
  .militaryTrainingRoutes: 31,  // MTR.txt: ~31k lines
  .terminalCommFacilities: 26,  // TWR.txt: ~26k lines
  .locationIdentifiers: 23,  // LID.txt: ~23k lines
  .ILSes: 11,  // ILS.txt: ~11k lines
  .navaids: 8,  // NAV.txt: ~8k lines
  .ARTCCFacilities: 7,  // AFF.txt: ~7k lines
  .ATSAirways: 4,  // ATS.txt: ~4k lines
  .weatherReportingLocations: 3,  // WXL.txt: ~3k lines
  .weatherReportingStations: 3,  // AWOS.txt: ~3k lines
  .ARTCCBoundarySegments: 3,  // ARB.txt: ~3k lines
  .parachuteJumpAreas: 2,  // PJA.txt: ~2k lines
  .FSSCommFacilities: 1,  // COM.txt: ~1k lines
  .miscActivityAreas: 1,  // MAA.txt: ~1k lines
  .flightServiceStations: 1  // FSS.txt: ~100 lines
]

/// Approximate total file sizes from live FAA distribution data (in MB).
/// These weights ensure progress bars advance proportionally to parsing work.
let CSVRecordWeights: [RecordType: Int64] = [
  .airports: 55,  // APT_*.csv + FRQ.csv: ~55MB total
  .reportingPoints: 17,  // FIX_*.csv: ~17MB total
  .terminalCommFacilities: 8,  // FRQ.csv: ~8MB
  .codedDepartureRoutes: 5,  // CDR.csv: ~5MB
  .airways: 4,  // AWY_*.csv: ~4MB total
  .ARTCCFacilities: 1,  // ATC_*.csv: ~1MB total
  .navaids: 1,  // NAV_BASE.csv: ~1MB
  .ILSes: 1,  // ILS_*.csv: ~0.5MB
  .weatherReportingStations: 1,  // AWOS.csv: ~0.5MB
  .flightServiceStations: 1  // FSS_BASE.csv: negligible
]

/// Weight for the initial loading phase (relative to parsing weights).
let loadingWeight: Int64 = 10

/// Record types parsed for TXT format.
let txtRecordTypes: Set<RecordType> = [
  .airports, .ARTCCFacilities, .flightServiceStations, .navaids, .reportingPoints,
  .weatherReportingStations, .airways, .ILSes, .terminalCommFacilities,
  .departureArrivalProceduresComplete, .preferredRoutes, .holds,
  .weatherReportingLocations, .parachuteJumpAreas, .militaryTrainingRoutes,
  .miscActivityAreas, .ARTCCBoundarySegments, .FSSCommFacilities, .ATSAirways,
  .locationIdentifiers
]

/// Record types parsed for CSV format.
let CSVRecordTypes: Set<RecordType> = [
  .airports, .ARTCCFacilities, .flightServiceStations, .navaids, .reportingPoints,
  .weatherReportingStations, .airways, .ILSes, .terminalCommFacilities,
  .codedDepartureRoutes
]

/// Returns the weight for a record type based on format.
func weight(for recordType: RecordType, isCSV: Bool) -> Int64 {
  if isCSV {
    return CSVRecordWeights[recordType] ?? 1
  }
  return txtRecordWeights[recordType] ?? 1
}

/// Calculates the total progress weight for a given format.
func totalWeight(isCSV: Bool) -> Int64 {
  let recordTypes = isCSV ? CSVRecordTypes : txtRecordTypes
  let weights = isCSV ? CSVRecordWeights : txtRecordWeights
  let recordTotal = recordTypes.reduce(0) { $0 + (weights[$1] ?? 1) }
  return loadingWeight + recordTotal
}
