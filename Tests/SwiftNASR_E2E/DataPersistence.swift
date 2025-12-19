import Foundation
import SwiftNASR

func saveData(
  nasr: NASR,
  formatName: String,
  workingDirectory: URL,
  selectedRecordTypes: Set<RecordType>
) async {
  // Print counts for each selected record type
  for recordType in selectedRecordTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
    guard let info = recordTypeRegistry[recordType] else { continue }
    let count = await getRecordCount(from: nasr.data, for: recordType) ?? 0
    print("\(formatName) - \(info.displayName): \(count)")
  }

  do {
    // Ensure working directory exists
    try FileManager.default.createDirectory(
      at: workingDirectory,
      withIntermediateDirectories: true
    )

    let encoder = JSONZipEncoder()
    let data = try await encoder.encode(NASRDataCodable(data: nasr.data))

    let outPath = workingDirectory.appendingPathComponent(
      "distribution_\(formatName.lowercased()).json.zip"
    )
    try data.write(to: outPath)
    print("\(formatName) JSON file written to \(outPath)")
  } catch {
    print("Error saving \(formatName): \(error)")
  }
}

func verifyCompletion(
  nasr: NASR,
  formatName: String,
  isCSV _: Bool,
  selectedRecordTypes: Set<RecordType>
) async {
  var missingTypes: [String] = []

  // Check each selected record type for completion
  for recordType in selectedRecordTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
    guard let info = recordTypeRegistry[recordType] else { continue }
    if await isRecordNil(in: nasr.data, for: recordType) {
      missingTypes.append(info.displayName)
    }
  }

  if !missingTypes.isEmpty {
    print("\n=== \(formatName) Completion Warning ===")
    print("The following record types failed to parse entirely:")
    for missingType in missingTypes {
      print("  - \(missingType)")
    }
  }
}
