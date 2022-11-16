import Foundation
import Combine

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

public protocol Loader {
    
    /**
     Asynchronously wraps downloaded data (or data loaded from disk or memory)
     in an appropriate ``Distribution`` implementation.
     
     - Parameter callback: Called when the data processing task is complete.
     - Parameter progressHandler: This block is called before processing begins
                                  with a Progress object you can use to track
                                  loading progress. You would add this object to
                                  your parent Progress object.
     - Parameter result: If successful, contains the distribution data wrapped
                         in the appropriate implementation. If not, contains the
                         error.
     */
    
    func load(withProgress progressHandler: @escaping (Progress) -> Void, callback: @escaping (_ result: Result<Distribution, Swift.Error>) -> Void)
    
    /**
     Asynchronously wraps downloaded data (or data loaded from disk or memory)
     in an appropriate ``Distribution`` implementation.
     
     - Parameter progressHandler: This block is called before processing begins
                                   with a Progress object you can use to track
                                   loading progress. You would add this object
                                   to your parent Progress object.
     - Returns: A publisher that publishes the distribution data wrapped in the
                appropriate implementation.
     */
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func loadPublisher(withProgress progressHandler: @escaping (Progress) -> Void) -> AnyPublisher<Distribution, Swift.Error>
    
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
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func load(withProgress progressHandler: @escaping (Progress) -> Void) async throws -> Distribution
}
