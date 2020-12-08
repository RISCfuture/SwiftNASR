import Foundation

/**
 Wraps distribution data in an `ArchiveFileDistribution`.
 */

public class ArchiveLoader: Loader {
    
    /// The location of the archive file on disk.
    public var location: URL
    
    /**
     Creates a loader that loads from a given location on disk.
     
     - Parameter location: The location of the archive file on disk.
     */

    public init(location: URL) {
        self.location = location
    }

    public func load(callback: @escaping (Result<Distribution, Swift.Error>) -> Void) {
        guard let distribution = ArchiveFileDistribution(location: location) else {
            callback(.failure(Error.badData))
            return
        }
        callback(.success(distribution))
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
