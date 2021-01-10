import Foundation
import Combine

/**
 Wraps distribution data in an `ArchiveFileDistribution`.
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

    public func load(callback: @escaping (Result<Distribution, Swift.Error>) -> Void) -> Progress {
        guard let distribution = ArchiveFileDistribution(location: location) else {
            callback(.failure(Error.badData))
            return Progress(totalUnitCount: 0)
        }
        callback(.success(distribution))
        return Progress(totalUnitCount: 0)
    }
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func load() -> AnyPublisher<Distribution, Swift.Error> {
        return Future { promise in
            self.queue.async {
                guard let distribution = ArchiveFileDistribution(location: self.location) else {
                    promise(.failure(Error.badData))
                    return
                }
                promise(.success(distribution))
            }
        }.eraseToAnyPublisher()
    }

    /// Errors that can occur when loading archive data.
    public enum Error: Swift.Error, CustomStringConvertible {
        
        /// The data was malformed.
        case badData
        
        public var description: String {
            switch self {
                case .badData:
                    return "Invalid archive data"
            }
        }
    }
}
