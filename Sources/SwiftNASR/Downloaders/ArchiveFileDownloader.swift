import Foundation

/**
 A downloader that downloads a distribution archive to a file on disk.
 */

public final class ArchiveFileDownloader: Downloader {
  public let cycle: Cycle

  /// The `URLSession` to use for downloading.
  public let session: URLSession

  /// The location to save the downloaded archive. If `nil`, saves to a
  /// tempfile.
  public let location: URL?

  public init(cycle: Cycle? = nil) {
    self.cycle = cycle ?? .current
    session = .shared
    location = nil
  }

  public init(cycle: Cycle? = nil, location: URL? = nil, session: URLSession = .shared) {
    self.cycle = cycle ?? .current
    self.location = location
    self.session = session
  }

  public func load(withProgress progressHandler: @Sendable (Progress) -> Void = { _ in })
    async throws -> Distribution
  {
    let delegate = DownloadDelegate()
    progressHandler(delegate.progress)

    let (tempfileURL, response) = try await session.download(from: cycleURL, delegate: delegate)

    let HTTPResponse = response as! HTTPURLResponse
    if HTTPResponse.statusCode / 100 != 2 { throw Error.badResponse(HTTPResponse) }

    if let location = self.location {
      try FileManager.default.copyItem(at: tempfileURL, to: location)
      return try ArchiveFileDistribution(location: location)
    }
    return try ArchiveFileDistribution(location: tempfileURL)
  }
}
