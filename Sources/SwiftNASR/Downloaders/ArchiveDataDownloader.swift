import Foundation

/**
 A downloader that downloads a distribution archive into memory. No data is
 saved to disk and no buffering is done.
 */

public final class ArchiveDataDownloader: Downloader {
  public let cycle: Cycle
  public let format: DataFormat

  /// The `URLSession` to use for downloading.
  public let session: URLSession

  public init(cycle: Cycle? = nil, format: DataFormat = .txt) {
    self.cycle = cycle ?? .current
    self.format = format
    session = .shared
  }

  public init(cycle: Cycle? = nil, format: DataFormat = .txt, session: URLSession = .shared) {
    self.cycle = cycle ?? .current
    self.format = format
    self.session = session
  }

  public func load(withProgress progressHandler: @Sendable (Progress) -> Void = { _ in })
    async throws -> Distribution
  {
    let delegate = DownloadDelegate()
    progressHandler(delegate.progress)

    let (data, response) = try await session.data(from: cycleURL, delegate: delegate)

    guard let HTTPResponse = response as? HTTPURLResponse else {
      throw Error.badResponse(response as! HTTPURLResponse)
    }

    // Check for non-success status codes
    if HTTPResponse.statusCode / 100 != 2 {
      throw Error.badResponse(HTTPResponse)
    }

    // Verify we got data
    guard !data.isEmpty else {
      throw Error.noData
    }

    return try ArchiveDataDistribution(data: data, format: format)
  }
}
