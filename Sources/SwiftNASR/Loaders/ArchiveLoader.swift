import Foundation
import Combine

/**
 Wraps distribution data in an ``ArchiveFileDistribution``.
 */

public class ArchiveLoader: Loader {
    
    /// The location of the archive file on disk.
    public var location: URL
    
    private let queue = DispatchQueue(label: "codes.tim.SwiftNASR.ArchiveLoader", qos: .utility, attributes: .concurrent)
    
    /**
     Creates a loader that loads from a given location on disk.
     
     - Parameter location: The location of the archive file on disk.
     */

    public init(location: URL) {
        self.location = location
    }

    public func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, callback: @escaping (Result<Distribution, Swift.Error>) -> Void) {
        progressHandler(completedProgress())
        do {
            let distribution = try ArchiveFileDistribution(location: location)
            callback(.success(distribution))
        } catch {
            callback(.failure(error))
        }
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func loadPublisher(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) -> AnyPublisher<Distribution, Swift.Error> {
        progressHandler(completedProgress())
        return Future { promise in
            self.queue.async {
                do {
                    let distribution = try ArchiveFileDistribution(location: self.location)
                    promise(.success(distribution))
                } catch {
                    promise(.failure(error))
                    return
                }
            }
        }.eraseToAnyPublisher()
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) async throws -> Distribution {
        progressHandler(completedProgress())
        
        return try ArchiveFileDistribution(location: location)
    }
}
