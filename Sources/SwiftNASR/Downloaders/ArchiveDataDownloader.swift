import Foundation

/**
 A downloader that downloads a distribution archive into memory. No data is
 saved to disk and no buffering is done.
 */

public final class ArchiveDataDownloader: Downloader {
    public let cycle: Cycle

    /// The `URLSession` to use for downloading.
    public let session: URLSession

    public init(cycle: Cycle? = nil) {
        self.cycle = cycle ?? .current
        session = .shared
    }

    public init(cycle: Cycle? = nil, session: URLSession = .shared) {
        self.cycle = cycle ?? .current
        self.session = session
    }

    public func load(withProgress progressHandler: @Sendable (Progress) -> Void = { _ in }) async throws -> Distribution {
        let delegate = DownloadDelegate()
        progressHandler(delegate.progress)
        
        let (data, response) = try await session.data(from: cycleURL, delegate: delegate)
        
        let HTTPResponse = response as! HTTPURLResponse
        if HTTPResponse.statusCode/100 != 2 { throw Error.badResponse(HTTPResponse) }
        
        return try ArchiveDataDistribution(data: data)
    }
}
