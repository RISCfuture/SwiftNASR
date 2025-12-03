import Foundation
@preconcurrency import ZIPFoundation

/**
 A NASR distribution that has been loaded from a ZIP archive and saved to a
 file. ZIPFoundation is used to extract the archive, which is loaded in buffered
 chunks.
 */

public final class ArchiveFileDistribution: Distribution {

  /// The compressed distribution file.
  public let location: URL

  private let archive: Archive

  private let chunkSize = defaultReadChunkSize
  private let delimiter = "\r\n".data(using: .isoLatin1)!

  /**
   Creates a new instance from the given file.
  
   - Parameter location: The path to the compressed distribution file.
   - Throws: If the archive could not be read.
   */

  public init(location: URL) throws {
    self.location = location
    let archive = try Archive(url: location, accessMode: .read)
    self.archive = archive
  }

  public func findFile(prefix: String) throws -> String? {
    return archive.first { $0.path.components(separatedBy: "/").last?.hasPrefix(prefix) ?? false }?
      .path
  }

  @discardableResult
  private func readFileWithCallback(
    path: String,
    withProgress progressHandler: (Progress) -> Void = { _ in },
    eachLine: (Data) -> Void
  ) throws -> UInt {
    guard let entry = archive[path] else { throw Error.noSuchFile(path: path) }
    var buffer = Data(capacity: Int(chunkSize))
    var lines: UInt = 0

    let progress = Progress(totalUnitCount: Int64(entry.uncompressedSize))
    progressHandler(progress)

    _ = try archive.extract(entry, bufferSize: chunkSize, skipCRC32: false, progress: nil) { data in
      buffer.append(data)
      Task { @MainActor in progress.completedUnitCount += Int64(data.count) }
      while let EOL = buffer.range(of: delimiter) {
        if EOL.startIndex == 0 {
          buffer.removeSubrange(EOL)
          continue
        }

        let subrange = buffer.startIndex..<EOL.lowerBound
        let subdata = buffer.subdata(in: subrange)

        eachLine(subdata)
        lines += 1

        buffer.removeSubrange(subrange)
      }
    }
    if !buffer.isEmpty {
      eachLine(buffer)
      lines += 1
    }

    return lines
  }

  public func readFile(
    path: String,
    withProgress progressHandler: (Progress) -> Void = { _ in },
    returningLines linesHandler: (UInt) -> Void = { _ in }
  ) -> AsyncThrowingStream<Data, Swift.Error> {
    return AsyncThrowingStream { continuation in
      do {
        let lines = try readFileWithCallback(path: path, withProgress: progressHandler) { data in
          continuation.yield(data)
        }
        linesHandler(lines)
        continuation.finish()
      } catch {
        continuation.finish(throwing: error)
      }
    }
  }
}
