import Foundation
import Testing
import ZIPFoundation

@testable import SwiftNASR

@Suite
struct ArchiveDataDistributionTests {
  private static var mockDataReadmePrefix: Data {
    get throws {
      let data = "Hello, world!\r\nLine 2".data(using: .isoLatin1)!
      let archive = try Archive(accessMode: .create)
      try archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) {
        (position: Int64, size: Int) in
        return data.subdata(in: Data.Index(position)..<(Int(position) + size))
      }
      let cycle = "AIS subscriber files effective date December 3, 2020.".data(using: .isoLatin1)!
      try archive.addEntry(
        with: "Read_me_8_Sep_2022.txt",
        type: .file,
        uncompressedSize: Int64(cycle.count)
      ) { (position: Int64, size: Int) in
        return cycle.subdata(in: Data.Index(position)..<(Int(position) + size))
      }
      return archive.data!
    }
  }

  private static var mockDataReadme: Data {
    get throws {
      let data = "Hello, world!\r\nLine 2".data(using: .isoLatin1)!
      let archive = try Archive(accessMode: .create)
      try archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) {
        (position: Int64, size: Int) in
        return data.subdata(in: Data.Index(position)..<(Int(position) + size))
      }
      let cycle = "AIS subscriber files effective date December 3, 2020.".data(using: .isoLatin1)!
      try archive.addEntry(with: "README.txt", type: .file, uncompressedSize: Int64(cycle.count)) {
        (position: Int64, size: Int) in
        return cycle.subdata(in: Data.Index(position)..<(Int(position) + size))
      }
      return archive.data!
    }
  }

  private let distributionReadme: ArchiveDataDistribution
  private let distributionPrefix: ArchiveDataDistribution

  init() throws {
    distributionReadme = try .init(data: Self.mockDataReadme)
    distributionPrefix = try .init(data: Self.mockDataReadmePrefix)
  }

  // MARK: readFile

  @Test
  func readsEachLineFromTheFile() async throws {
    var iter = 0
    var progress = Progress(totalUnitCount: 0)

    let stream = await distributionReadme.readFile(path: "APT.TXT") { progress = $0 }
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
  func throwsAnErrorIfTheFileDoesntExist() async {
    await #expect {
      let stream = await distributionReadme.readFile(path: "unknown")
      for try await foo in stream { print(foo) }
    } throws: { error in
      guard let error = error as? SwiftNASR.Error, case .noSuchFile = error else { return false }
      return true
    }
  }

  // MARK: readCycle

  @Test
  func readsTheCycleFromTheREADMEFile() async throws {
    let cycle = try #require(try await distributionReadme.readCycle())
    #expect(cycle.year == 2020)
    #expect(cycle.month == 12)
    #expect(cycle.day == 3)
  }

  @Test
  func readsTheCycleFromTheReadMePrefixFile() async throws {
    let cycle = try #require(try await distributionPrefix.readCycle())
    #expect(cycle.year == 2020)
    #expect(cycle.month == 12)
    #expect(cycle.day == 3)
  }
}
