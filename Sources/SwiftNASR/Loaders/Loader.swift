import Foundation

func completedProgress() -> Progress {
    let progress = Progress(totalUnitCount: 1)
    progress.completedUnitCount = 1
    return progress
}

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
     
     - Parameter progressHandler: This block is called before processing begins
                                  with a Progress object you can use to track
                                  loading progress. You would add this object to
                                  your parent Progress object.
     - Returns: The distribution data wrapped in the appropriate implementation,
                and an object you can use to track progress.
     */

    func load(withProgress progressHandler: @Sendable (Progress) -> Void) async throws -> Distribution
}
