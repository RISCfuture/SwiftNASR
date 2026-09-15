public import Foundation

/**
 Loaders create a ``Distribution`` from a NASR archive, on disk, in memory, or
 downloaded from the Internet (see ``Downloader``). For example,
 ``ArchiveDataDownloader`` produces a ZIP-compressed archive, and so the
 data would need to be handled by ``ArchiveDataDistribution``. The
 ``ArchiveLoader`` implementation mediates between the two classes.
 */

public protocol Loader: Sendable {

  /**
   Asynchronously wraps downloaded data (or data loaded from disk or memory)
   in an appropriate ``Distribution`` implementation.

   - Parameter progress: A subprogress, obtained from your own `ProgressManager`, that reports
                         loading progress. Pass `nil` to track no progress.
   - Returns: The distribution data wrapped in the appropriate implementation.
   */

  func load(progress: consuming Subprogress?) async throws -> any Distribution
}
