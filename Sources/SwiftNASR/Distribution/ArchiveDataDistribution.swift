import Foundation
@preconcurrency import ZIPFoundation

/**
 A NASR distribution that has been loaded from a ZIP archive and stored in
 memory. ZIPFoundation is used to extract the archive, which is loaded in
 buffered chunks.
 */

public final class ArchiveDataDistribution: Distribution {

  /// The compressed distribution data.
  public let data: Data

  /// The data format (TXT or CSV) for this distribution
  public let format: DataFormat

  private let archive: Archive

  private let chunkSize = defaultReadChunkSize
  private let crlfDelimiter = "\r\n".data(using: .isoLatin1)!
  private let lfDelimiter = "\n".data(using: .isoLatin1)!

  /**
   Creates a new instance from the given data.
  
   - Parameter data: The compressed distribution.
   - Parameter format: The data format (defaults to .txt for backward compatibility)
   - Throws: If the archive could not be read.
   */

  public init(data: Data, format: DataFormat = .txt) throws {
    self.data = data
    self.format = format
    let archive = try Archive(data: data, accessMode: .read, pathEncoding: .ascii)
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
    // Try exact match first, then case-insensitive match
    let entry =
      archive[path] ?? archive.first { $0.path.caseInsensitiveCompare(path) == .orderedSame }
    guard let entry else { throw Error.noSuchFile(path: path) }
    var buffer = Data(capacity: Int(chunkSize))
    var lines: UInt = 0

    let progress = Progress(totalUnitCount: Int64(entry.uncompressedSize))
    progressHandler(progress)

    _ = try archive.extract(entry, bufferSize: chunkSize, skipCRC32: false, progress: nil) { data in
      buffer.append(data)
      Task { @MainActor in progress.completedUnitCount += Int64(data.count) }
      // Handle both \r\n and \n line endings
      while true {
        let crlfRange = buffer.range(of: crlfDelimiter)
        let lfRange = buffer.range(of: lfDelimiter)

        let EOL: Range<Data.Index>?
        if let crlf = crlfRange, let lf = lfRange {
          EOL = crlf.lowerBound < lf.lowerBound ? crlf : lf
        } else {
          EOL = crlfRange ?? lfRange
        }

        guard let EOL else { break }

        if EOL.startIndex == 0 {
          buffer.removeSubrange(EOL)
          continue
        }

        let subrange = buffer.startIndex..<EOL.lowerBound
        let subdata = buffer.subdata(in: subrange)

        eachLine(subdata)
        lines += 1

        buffer.removeSubrange(buffer.startIndex..<EOL.upperBound)
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

  public func readCycle() async throws -> Cycle? {
    if format == .csv {
      // For CSV format, we can't determine cycle from data alone
      // The cycle should be provided when creating the distribution
      // Return nil to use current date
      return nil
    }
    // For TXT format, use the default implementation that reads from README
    let path = try findFile(prefix: "Read_me") ?? "README.txt"
    let lines: AsyncThrowingStream = await readFile(
      path: path,
      withProgress: { _ in },
      returningLines: { _ in }
    )
    for try await line in lines
    where line.starts(with: "AIS subscriber files effective date ".data(using: .isoLatin1)!) {
      return parseCycleFromReadme(line)
    }
    return nil
  }

  private func parseCycleFromReadme(_ line: Data) -> Cycle? {
    let readmeFirstLine = "AIS subscriber files effective date ".data(using: .isoLatin1)!
    let cycleDateData = line[readmeFirstLine.count..<(line.count - 1)]
    guard let cycleDateString = String(data: cycleDateData, encoding: .isoLatin1) else {
      return nil
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "MMMM d, yyyy"

    guard let cycleDate = formatter.date(from: cycleDateString) else {
      return nil
    }

    let cycleComponents = Calendar(identifier: .gregorian).dateComponents(
      in: TimeZone(identifier: "UTC")!,
      from: cycleDate
    )
    guard let year = cycleComponents.year else { return nil }
    guard let month = cycleComponents.month else { return nil }
    guard let day = cycleComponents.day else { return nil }

    return Cycle(year: UInt(year), month: UInt8(month), day: UInt8(day))
  }
}
