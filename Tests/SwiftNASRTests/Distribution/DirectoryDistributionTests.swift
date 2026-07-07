import Foundation
import Testing
import ZIPFoundation

@testable import SwiftNASR

@Suite
struct DirectoryDistributionTests {
  private func makeDistribution() throws -> (DirectoryDistribution, URL) {
    let mockData = "Hello, world!\r\nLine 2".data(using: .isoLatin1)!
    let tempdir = FileManager.default.temporaryDirectory.appendingPathComponent(
      ProcessInfo.processInfo.globallyUniqueString
    )
    try FileManager.default.createDirectory(at: tempdir, withIntermediateDirectories: true)
    try mockData.write(to: tempdir.appendingPathComponent("APT.TXT"))
    return (DirectoryDistribution(location: tempdir), tempdir)
  }

  @Test
  func readsEachLineFromTheFile() async throws {
    let (distribution, tempdir) = try makeDistribution()
    defer { try? FileManager.default.removeItem(at: tempdir) }

    var iter = 0
    var progress = Progress(totalUnitCount: 0)

    let stream = await distribution.readFile(path: "APT.TXT") { progress = $0 }

    for try await data in stream {
      if iter == 0 {
        #expect(progress.completedUnitCount == 35)
        #expect(data == "Hello, world!".data(using: .isoLatin1)!)
      } else if iter == 1 {
        #expect(data == "Line 2".data(using: .isoLatin1)!)
      } else {
        Issue.record("too many lines")
      }

      iter += 1
    }
  }

  @Test
  func throwsAnErrorIfTheFileDoesntExist() async throws {
    let (distribution, tempdir) = try makeDistribution()
    defer { try? FileManager.default.removeItem(at: tempdir) }

    await #expect {
      let stream = await distribution.readFile(path: "unknown")
      for try await _ in stream {}
    } throws: { error in
      guard let error = error as? SwiftNASR.Error, case .noSuchFile = error else { return false }
      return true
    }
  }
}
