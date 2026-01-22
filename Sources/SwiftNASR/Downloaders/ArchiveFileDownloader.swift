import Foundation

/**
 A downloader that downloads a distribution archive to a file on disk.
 */

public final class ArchiveFileDownloader: Downloader {
  public let cycle: Cycle
  public let format: DataFormat

  /// The `URLSession` to use for downloading.
  public let session: URLSession

  /// The location to save the downloaded archive. If `nil`, saves to a
  /// tempfile.
  public let location: URL?

  public init(cycle: Cycle? = nil, format: DataFormat = .txt) {
    self.cycle = cycle ?? .effective
    self.format = format
    session = .shared
    location = nil
  }

  public init(
    cycle: Cycle? = nil,
    format: DataFormat = .txt,
    location: URL? = nil,
    session: URLSession = .shared
  ) {
    self.cycle = cycle ?? .effective
    self.format = format
    self.location = location
    self.session = session
  }

  public func load(withProgress progressHandler: @Sendable (Progress) -> Void = { _ in })
    async throws -> Distribution
  {
    let delegate = DownloadDelegate()
    progressHandler(delegate.progress)

    let (tempfileURL, response) = try await session.download(from: cycleURL, delegate: delegate)

    guard let HTTPResponse = response as? HTTPURLResponse else {
      throw Error.badResponse(response as! HTTPURLResponse)
    }

    // Check for non-success status codes
    if HTTPResponse.statusCode / 100 != 2 {
      // Clean up temp file if it exists
      try? FileManager.default.removeItem(at: tempfileURL)
      throw Error.badResponse(HTTPResponse)
    }

    // Verify the downloaded file exists and has content
    guard FileManager.default.fileExists(atPath: tempfileURL.path) else {
      throw Error.downloadFailed(reason: "Downloaded file does not exist")
    }

    let fileSize =
      try FileManager.default.attributesOfItem(atPath: tempfileURL.path)[.size] as? Int64 ?? 0
    if fileSize == 0 {
      try? FileManager.default.removeItem(at: tempfileURL)
      throw Error.downloadFailed(reason: "Downloaded file is empty")
    }

    if let location = self.location {
      // Remove existing file if present
      try? FileManager.default.removeItem(at: location)
      try FileManager.default.moveItem(at: tempfileURL, to: location)
      return try ArchiveFileDistribution(location: location, format: format)
    }
    return try ArchiveFileDistribution(location: tempfileURL, format: format)
  }
}
