import Foundation
import Testing
import ZIPFoundation

@testable import SwiftNASR

@Suite
struct ArchiveLoaderTests {
  private static var mockData: Data {
    get throws {
      let data = "Hello, world!".data(using: .isoLatin1)!
      let archive = try Archive(accessMode: .create)
      try archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) {
        (position: Int64, size: Int) in
        return data.subdata(in: Data.Index(position)..<(Int(position) + size))
      }
      return archive.data!
    }
  }

  @Test
  func callsBackWithTheArchive() throws {
    let location = FileManager.default.temporaryDirectory.appendingPathComponent(
      ProcessInfo().globallyUniqueString
    )
    try Self.mockData.write(to: location)
    defer { try? FileManager.default.removeItem(at: location) }

    let loader = ArchiveLoader(location: location)
    let distribution = try loader.load() as! ArchiveFileDistribution
    #expect(distribution.location == location)
  }
}
