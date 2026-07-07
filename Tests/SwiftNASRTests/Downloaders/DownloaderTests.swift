import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Testing
import ZIPFoundation

@testable import SwiftNASR

/// The downloader tests share the process-global `MockURLProtocol` response
/// fixture, so they are serialized to keep concurrent tests from consuming each
/// other's stubbed responses. `.serialized` is repeated on each nested suite
/// because older swift-testing runtimes (as shipped with Swift 6.1) don't
/// reliably propagate it from an enclosing suite down to nested ones.
///
/// On Linux, `URLSession` + a mocked `URLProtocol` is unreliable under real test-suite load:
/// `.download(from:)` crashes outright (see `ArchiveFileDownloaderTests` below), and even
/// `.data(from:)` can intermittently lose a stubbed response to a stray, out-of-band
/// `URLProtocol` callback that lands between two serialized tests — a swift-corelibs-foundation
/// limitation, not a SwiftNASR bug. `ArchiveDataDownloader` and `ArchiveFileDownloader`'s
/// production download paths are exercised by SwiftNASR_E2E against the real FAA endpoint instead.
#if canImport(FoundationNetworking)
  @Suite(
    .serialized,
    .disabled("URLSession + a mocked URLProtocol is unreliable under load on Linux")
  )
#else
  @Suite(.serialized)
#endif
enum DownloaderTests {
  fileprivate static let mockURL = URL(string: "http://test.host")!
  fileprivate static let expectedURL =
    "https://nfdc.faa.gov/webContent/28DaySub/28DaySubscription_Effective_2020-01-30.zip"

  fileprivate static func mockArchive() throws -> Data {
    let data = "Hello, world!".data(using: .isoLatin1)!
    let archive = try Archive(accessMode: .create)
    try archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) {
      (position: Int64, size: Int) in
      return data.subdata(in: Data.Index(position)..<(Int(position) + size))
    }
    return archive.data!
  }

  fileprivate static func mockSession() -> URLSession {
    let sessionConfig = URLSessionConfiguration.ephemeral
    sessionConfig.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: sessionConfig)
  }

  @Suite(.serialized)
  struct ArchiveDataDownloaderTests {
    private func downloader() -> ArchiveDataDownloader {
      ArchiveDataDownloader(
        cycle: Cycle(year: 2020, month: 1, day: 30),
        session: DownloaderTests.mockSession()
      )
    }

    @Test
    func callsBackWithTheData() async throws {
      let mockData = try DownloaderTests.mockArchive()
      let response = HTTPURLResponse(
        url: DownloaderTests.mockURL,
        statusCode: 200,
        httpVersion: "1.1",
        headerFields: [:]
      )
      MockURLProtocol.nextResponse = .init(data: mockData, response: response)

      let distribution = try await downloader().load() as! ArchiveDataDistribution
      #expect(distribution.data == mockData)
      #expect(MockURLProtocol.lastURL!.absoluteString == DownloaderTests.expectedURL)
    }

    @Test
    func callsBackWithAnErrorForABadHTTPCode() async throws {
      let response = HTTPURLResponse(
        url: DownloaderTests.mockURL,
        statusCode: 404,
        httpVersion: "1.1",
        headerFields: [:]
      )
      MockURLProtocol.nextResponse = try .init(
        data: DownloaderTests.mockArchive(),
        response: response
      )

      await #expect {
        try await downloader().load()
      } throws: { error in
        guard let error = error as? SwiftNASR.Error, case .badResponse = error else { return false }
        return true
      }
    }

    @Test
    func callsBackWithAnErrorForAnHTTPError() async {
      MockURLProtocol.nextResponse = .init(
        error: NSError(domain: "TestDomain", code: -1, userInfo: [:])
      )

      await #expect {
        try await downloader().load()
      } throws: { error in
        let nsError = error as NSError
        return nsError.domain == "TestDomain" && nsError.code == -1
      }
    }
  }

  // swift-corelibs-foundation's `URLSession.download(from:delegate:)` crashes on completion when
  // the mocked `URLProtocol` finishes loading via `didLoad(data:)` instead of writing an actual
  // file to disk — a Linux Foundation limitation, not a SwiftNASR bug. `ArchiveFileDownloader`'s
  // production download path is exercised by SwiftNASR_E2E against the real FAA endpoint instead.
  #if canImport(FoundationNetworking)
    @Suite(.disabled("URLSession.download(from:) + a mocked URLProtocol crashes on Linux"))
  #else
    @Suite(.serialized)
  #endif
  struct ArchiveFileDownloaderTests {
    private func downloader() -> ArchiveFileDownloader {
      ArchiveFileDownloader(
        cycle: Cycle(year: 2020, month: 1, day: 30),
        session: DownloaderTests.mockSession()
      )
    }

    @Test
    func callsBackWithTheFile() async throws {
      let mockData = try DownloaderTests.mockArchive()
      let response = HTTPURLResponse(
        url: DownloaderTests.mockURL,
        statusCode: 200,
        httpVersion: "1.1",
        headerFields: [:]
      )
      MockURLProtocol.nextResponse = .init(data: mockData, response: response)

      let distribution = try await downloader().load() as! ArchiveFileDistribution
      #expect(try Data(contentsOf: distribution.location) == mockData)
      #expect(MockURLProtocol.lastURL!.absoluteString == DownloaderTests.expectedURL)
    }

    @Test
    func callsBackWithAnErrorForABadHTTPCode() async throws {
      let response = HTTPURLResponse(
        url: DownloaderTests.mockURL,
        statusCode: 404,
        httpVersion: "1.1",
        headerFields: [:]
      )
      MockURLProtocol.nextResponse = try .init(
        data: DownloaderTests.mockArchive(),
        response: response
      )

      await #expect {
        try await downloader().load()
      } throws: { error in
        guard let error = error as? SwiftNASR.Error, case .badResponse = error else { return false }
        return true
      }
    }

    @Test
    func callsBackWithAnErrorForAnHTTPError() async {
      MockURLProtocol.nextResponse = .init(
        error: NSError(domain: "TestDomain", code: -1, userInfo: [:])
      )

      await #expect {
        try await downloader().load()
      } throws: { error in
        let nsError = error as NSError
        return nsError.domain == "TestDomain" && nsError.code == -1
      }
    }
  }
}
