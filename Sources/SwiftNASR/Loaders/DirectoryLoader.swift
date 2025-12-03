import Foundation

/**
 Wraps distribution data in an ``DirectoryDistribution``.
 */

public final class DirectoryLoader: Loader {

  /// The location of the distribution directory on disk.
  public let location: URL

  /**
   Creates a loader that loads from a given location on disk.
  
   - Parameter location: The location of the distribution directory on disk.
   */

  public init(location: URL) {
    self.location = location
  }

  public func load(withProgress progressHandler: @Sendable (Progress) -> Void = { _ in }) throws
    -> Distribution
  {
    progressHandler(completedProgress())
    return DirectoryDistribution(location: location)
  }
}
