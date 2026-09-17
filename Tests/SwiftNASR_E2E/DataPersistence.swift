import Foundation
import SwiftNASR

/// Encodes the parsed data to a zipped JSON file in `workingDirectory`.
func saveData(nasr: NASR, format: DataFormat, workingDirectory: URL) async throws {
  try FileManager.default.createDirectory(
    at: workingDirectory,
    withIntermediateDirectories: true
  )

  let encoder = JSONZipEncoder()
  let data = try await encoder.encode(NASRDataCodable(data: nasr.data))

  let outPath = workingDirectory.appendingPathComponent(
    "distribution_\(format.rawValue.lowercased()).json.zip"
  )
  try data.write(to: outPath)
  print("\(format.rawValue) JSON file written to \(outPath)")
}
