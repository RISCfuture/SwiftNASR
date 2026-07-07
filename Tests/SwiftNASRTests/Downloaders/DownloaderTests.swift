import Foundation
import Testing
import ZIPFoundation

@testable import SwiftNASR

/// The downloader tests share the process-global `MockURLProtocol` response
/// fixture, so they are serialized to keep concurrent tests from consuming each
/// other's stubbed responses.
@Suite(.serialized)
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

  @Suite
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

  @Suite
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
