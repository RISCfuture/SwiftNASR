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

    public func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, callback: @escaping (Result<Distribution, Swift.Error>) -> Void) {
        progressHandler(completedProgress)
        callback(.success(DirectoryDistribution(location: location)))
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func loadPublisher(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) -> AnyPublisher<Distribution, Swift.Error> {
        progressHandler(completedProgress)
        return Result.Publisher(DirectoryDistribution(location: location)).eraseToAnyPublisher()
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) async throws -> Distribution {
        progressHandler(completedProgress)
        return DirectoryDistribution(location: location)
    }
}
