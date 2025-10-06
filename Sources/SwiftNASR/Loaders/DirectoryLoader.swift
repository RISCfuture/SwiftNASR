import Foundation

/**
 Wraps distribution data in an ``DirectoryDistribution``.
 */

public final class DirectoryLoader: Loader {

  /// The location of the distribution directory on disk.
  public let location: URL

  /// The data format for the distribution.
  public let format: DataFormat

  /**
   Creates a loader that loads from a given location on disk.
  
   - Parameter location: The location of the distribution directory on disk.
   - Parameter format: The data format (defaults to .txt for backward compatibility)
   */

  public init(location: URL, format: DataFormat = .txt) {
    self.location = location
    self.format = format
  }

  public func load(withProgress progressHandler: @Sendable (Progress) -> Void = { _ in })
    throws -> Distribution
  {
    progressHandler(completedProgress())
    return DirectoryDistribution(location: location, format: format)
  }
}
