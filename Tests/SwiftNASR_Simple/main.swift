import Foundation
import SwiftNASR

print("Test program starting...")

let txtPath = URL(
  fileURLWithPath:
    "/Users/tmorgan/Repositories/Libraries/SwiftNASR/.SwiftNASR_TestData/distribution_txt.zip"
)

print("TXT archive path: \(txtPath.path)")
print("File exists: \(FileManager.default.fileExists(atPath: txtPath.path))")

if FileManager.default.fileExists(atPath: txtPath.path) {
  let fileSize = try? FileManager.default.attributesOfItem(atPath: txtPath.path)[.size] as? Int64
  print("File size: \(fileSize ?? 0) bytes")

  print("Creating NASR instance...")
  let nasr = NASR.fromLocalArchive(txtPath)
  print("NASR created!")

  print("About to call nasr.load()...")
  Task {
    do {
      try await nasr.load { progress in
        print("Load progress: \(progress.fractionCompleted)")
      }
      print("Load completed successfully!")
    } catch {
      print("Load failed: \(error)")
    }
    exit(0)
  }

  RunLoop.main.run()
} else {
  print("TXT archive not found")
}
