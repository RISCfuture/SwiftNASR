import Foundation
import Combine

/**
 Wraps distribution data in an `DirectoryDistribution`.
 */

public class DirectoryLoader: Loader {
    
    /// The location of the distribution directory on disk.
    public var location: URL
    
    /**
     Creates a loader that loads from a given location on disk.
     
     - Parameter location: The location of the distribution directory on disk.
     */

    public init(location: URL) {
        self.location = location
    }

    public func load(callback: @escaping (Result<Distribution, Swift.Error>) -> Void) -> Progress {
        callback(.success(DirectoryDistribution(location: location)))
        return completedProgress
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func loadPublisher() -> AnyPublisher<Distribution, Swift.Error> {
        return Result.Publisher(DirectoryDistribution(location: location)).eraseToAnyPublisher()
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func load(progress: inout Progress) async throws -> Distribution {
        progress = completedProgress
        return DirectoryDistribution(location: location)
    }
}
