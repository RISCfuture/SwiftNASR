import Foundation

/**
 Wraps distribution data in an ``ArchiveFileDistribution``.
 */

public final class ArchiveLoader: Loader {

    /// The location of the archive file on disk.
    public let location: URL

    private let queue = DispatchQueue(label: "codes.tim.SwiftNASR.ArchiveLoader", qos: .utility, attributes: .concurrent)

    /**
     Creates a loader that loads from a given location on disk.
     
     - Parameter location: The location of the archive file on disk.
     */

    public init(location: URL) {
        self.location = location
    }

    public func load(withProgress progressHandler: @Sendable (Progress) -> Void = { _ in }) throws -> Distribution {
        progressHandler(completedProgress())

        return try ArchiveFileDistribution(location: location)
    }
}
