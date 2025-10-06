import Foundation
import SwiftNASR

print("1. Test program starting...")

let testPath = URL(
  fileURLWithPath:
    "/Users/tmorgan/Repositories/Libraries/SwiftNASR/.SwiftNASR_TestData/distribution_txt.zip"
)

print("2. Test archive: \(testPath.path)")
print("3. File exists: \(FileManager.default.fileExists(atPath: testPath.path))")

if FileManager.default.fileExists(atPath: testPath.path) {
  print("4. About to create NASR from archive...")
  let nasr = NASR.fromLocalArchive(testPath)
  print("5. NASR created successfully!")

  print("6. Starting async load...")
  Task {
    do {
      print("7. Inside Task, calling nasr.load()...")
      try await nasr.load { progress in
        print("Progress: \(Int(progress.fractionCompleted * 100))%")
      }
      print("8. Load completed!")
      exit(0)
    } catch {
      print("Load error: \(error)")
      exit(1)
    }
  }

  print("9. Task created, running RunLoop...")
  RunLoop.main.run()
}
