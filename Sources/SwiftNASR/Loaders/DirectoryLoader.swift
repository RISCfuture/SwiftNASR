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

    public func load(callback: @escaping (Result<Distribution, Error>) -> Void) {
        callback(.success(DirectoryDistribution(location: location)))
    }
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func load() -> AnyPublisher<Distribution, Swift.Error> {
        return Result.Publisher(DirectoryDistribution(location: location)).eraseToAnyPublisher()
    }
}
