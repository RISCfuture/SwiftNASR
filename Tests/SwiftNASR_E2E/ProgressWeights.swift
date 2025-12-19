import SwiftNASR

/// Weight for the initial loading phase (relative to parsing weights).
let loadingWeight: Int64 = 10

/// Returns the weight for a record type based on format.
func weight(for recordType: RecordType, isCSV: Bool) -> Int64 {
  recordTypeRegistry[recordType]?.weight(isCSV: isCSV) ?? 1
}

/// Record types parsed for TXT format.
var txtRecordTypes: Set<RecordType> {
  Set(recordTypeRegistry.values.filter(\.availableInTXT).map(\.recordType))
}

/// Record types parsed for CSV format.
var CSVRecordTypes: Set<RecordType> {
  Set(recordTypeRegistry.values.filter(\.availableInCSV).map(\.recordType))
}

/// Calculates the total progress weight for a given format.
func totalWeight(isCSV: Bool) -> Int64 {
  let recordTypes = isCSV ? CSVRecordTypes : txtRecordTypes
  let recordTotal = recordTypes.reduce(0) { $0 + weight(for: $1, isCSV: isCSV) }
  return loadingWeight + recordTotal
}

/// Calculates the total progress weight for selected record types.
func totalWeight(isCSV: Bool, selectedRecordTypes: Set<RecordType>) -> Int64 {
  let recordTotal = selectedRecordTypes.reduce(0) { $0 + weight(for: $1, isCSV: isCSV) }
  return loadingWeight + recordTotal
}
