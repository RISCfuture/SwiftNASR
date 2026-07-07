import Foundation
import Testing
import ZIPFoundation

@testable import SwiftNASR

@Suite
struct ArchiveFileDistributionTests {
  private static var mockData: Data {
    get throws {
      let data = "Hello, world!\r\nLine 2".data(using: .isoLatin1)!
      let archive = try Archive(accessMode: .create)
      try archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) {
        (position: Int64, size: Int) in
        return data.subdata(in: Data.Index(position)..<(Int(position) + size))
      }
      return archive.data!
    }
  }

  private func makeDistribution() throws -> (ArchiveFileDistribution, URL) {
    let tempfile = FileManager.default.temporaryDirectory.appendingPathComponent(
      ProcessInfo.processInfo.globallyUniqueString
    )
    try Self.mockData.write(to: tempfile)
    return (try .init(location: tempfile), tempfile)
  }

  @Test
  func readsEachLineFromTheFile() async throws {
    let (distribution, tempfile) = try makeDistribution()
    defer { try? FileManager.default.removeItem(at: tempfile) }

    var iter = 0
    var progress = Progress(totalUnitCount: 0)

    let stream = await distribution.readFile(path: "APT.TXT") { progress = $0 }
    #expect(progress.completedUnitCount == 21)

    for try await data in stream {
      if iter == 0 {
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
    let (distribution, tempfile) = try makeDistribution()
    defer { try? FileManager.default.removeItem(at: tempfile) }

    await #expect {
      let data = await distribution.readFile(path: "unknown")
      for try await _ in data {}
    } throws: { error in
      guard let error = error as? SwiftNASR.Error, case .noSuchFile = error else { return false }
      return true
    }
  }
}
