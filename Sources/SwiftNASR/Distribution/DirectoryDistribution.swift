import Foundation

/**
 A NASR distribution that has been loaded from a directory of decompressed
 archive files.
 */

public final class DirectoryDistribution: Distribution {

  /// The directory containing the distribution files.
  public let location: URL

  /// The data format (TXT or CSV) for this distribution
  public let format: DataFormat

  private let chunkSize = 4096
  private let delimiter = "\r\n".data(using: .isoLatin1)!

  /**
   Creates a new instance from the given directory.
  
   - Parameter location: The path to the distribution directory.
   - Parameter format: The data format (defaults to .txt for backward compatibility)
   */

  public init(location: URL, format: DataFormat = .txt) {
    self.location = location
    self.format = format
  }

  public func findFile(prefix: String) throws -> String? {
    let children = try FileManager.default.contentsOfDirectory(
      at: location,
      includingPropertiesForKeys: [.nameKey]
    )
    return children.first { $0.lastPathComponent.hasPrefix(prefix) }?.lastPathComponent
  }

  @discardableResult
  private func readFileWithCallback(
    path: String,
    withProgress progressHandler: (Progress) -> Void = { _ in },
    eachLine: (Data) -> Void
  ) throws -> UInt {
    let fileURL = location.appendingPathComponent(path)
    let handle: FileHandle
    do {
      handle = try FileHandle(forReadingFrom: fileURL)
    } catch let error as NSError {
      if error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
        throw Error.noSuchFile(path: path)
      }
      throw error
    }
    var buffer = Data(capacity: chunkSize)
    let filesize =
      try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as! NSNumber
    var lines: UInt = 0

    let progress = Progress(totalUnitCount: filesize.int64Value)
    progressHandler(progress)

    while true {
      if let EOL = buffer.range(of: delimiter) {
        if EOL.lowerBound == 0 {
          buffer.removeSubrange(EOL)
          continue
        }

        let subrange = buffer.startIndex..<EOL.lowerBound
        let subdata = buffer.subdata(in: subrange)
        Task { @MainActor in progress.completedUnitCount += Int64(subdata.count) }

        eachLine(subdata)
        lines += 1

        buffer.removeSubrange(subrange)
      } else {
        let data = handle.readData(ofLength: chunkSize)
        Task { @MainActor in progress.completedUnitCount += Int64(data.count) }
        guard !data.isEmpty else {
          if !buffer.isEmpty {
            eachLine(buffer)
            lines += 1
          }
          return lines
        }
        buffer.append(data)
      }
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

  public func readCycle() throws -> Cycle? {
    if format == .csv {
      // For CSV distributions, try to parse cycle from directory name
      let dirName = location.lastPathComponent
      // Expected format: DD_MMM_YYYY_CSV (e.g., 04_Sep_2025_CSV)
      return parseCycleFromCSVDateString(dirName)
    }
    // For TXT format, use the default implementation from Distribution extension
    // First check if there's a README file
    let path = try findFile(prefix: "Read_me") ?? "README.txt"
    let fileURL = location.appendingPathComponent(path)

    // Check if the file exists
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return nil
    }

    // Read the file content and parse the cycle
    do {
      let content = try String(contentsOf: fileURL, encoding: .isoLatin1)
      let lines = content.components(separatedBy: .newlines)
      for line in lines where line.hasPrefix("AIS subscriber files effective date ") {
        let dateString = String(line.dropFirst("AIS subscriber files effective date ".count))
          .trimmingCharacters(in: .whitespaces)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!
        formatter.dateFormat = "MMMM d, yyyy"

        if let date = formatter.date(from: dateString) {
          let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(secondsFromGMT: 0)!,
            from: date
          )
          if let year = components.year,
            let month = components.month,
            let day = components.day
          {
            return Cycle(year: UInt(year), month: UInt8(month), day: UInt8(day))
          }
        }
      }
    } catch {
      // If we can't read the file, return nil
      return nil
    }
    return nil
  }
}
