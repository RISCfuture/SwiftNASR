import Foundation
import Combine

/**
 Loaders create the appropriate `Distribution` for a `Downloader`. For example,
 the `ArchiveDataDownloader` produces a ZIP-compressed archive, and so the
 data would need to be handled by `ArchiveDataDistribution`. The `ArchiveLoader`
 implementation mediates between the two classes.
 */

public protocol Loader {
    
    /**
     Asynchronously wraps downloaded data (or data loaded from disk or memory)
     in an appropriate `Distribution` implementation.
     
     - Parameter callback: Called when the data processing task is complete.
     - Parameter result: If successful, contains the distribution data wrapped
                         in the appropriate implementation. If not, contains the
                         error.
     - Returns: A progress value that is updated during the loading process.
     */
    
    func load(callback: @escaping (_ result: Result<Distribution, Swift.Error>) -> Void) -> Progress
    
    /**
     Asynchronously wraps downloaded data (or data loaded from disk or memory)
     in an appropriate `Distribution` implementation.
     
     - Returns: A publisher that publishes the distribution data wrapped in the
                appropriate implementation.
     */
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func load() -> AnyPublisher<Distribution, Swift.Error>
}
