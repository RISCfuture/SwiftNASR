import Foundation
import Testing

@testable import SwiftNASR

@Suite
struct DirectoryLoaderTests {
  @Test
  func `calls back with the directory`() throws {
    let location = FileManager.default.temporaryDirectory
      .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
    let loader = DirectoryLoader(location: location)

    let distribution = try loader.load() as! DirectoryDistribution
    #expect(distribution.location == location)
  }
}
