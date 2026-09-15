import SwiftNASR

/// Weight for the initial loading phase (relative to parsing weights).
let loadingWeight: Int = 10

/// Returns the weight for a record type based on format.
func weight(for recordType: RecordType, format: DataFormat) -> Int {
  recordTypeRegistry[recordType]?.weight(for: format) ?? 1
}

/// Record types a format carries.
func availableRecordTypes(for format: DataFormat) -> Set<RecordType> {
  Set(recordTypeRegistry.values.filter { $0.isAvailable(in: format) }.map(\.recordType))
}

/// Calculates the total progress weight for selected record types.
func totalWeight(format: DataFormat, selectedRecordTypes: Set<RecordType>) -> Int {
  let recordTotal = selectedRecordTypes.reduce(0) { $0 + weight(for: $1, format: format) }
  return loadingWeight + recordTotal
}
