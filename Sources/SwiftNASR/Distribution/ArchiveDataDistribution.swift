import Foundation
import ZIPFoundation

/**
 A NASR distribution that has been loaded from a ZIP archive and stored in
 memory. ZIPFoundation is used to extract the archive, which is loaded in
 buffered chunks.
 */

public class ArchiveDataDistribution: Distribution {
    
    /// The compressed distribution data.
    public let data: Data
    
    private let archive: Archive

    private var chunkSize = defaultReadChunkSize
    private var delimiter = "\r\n".data(using: .ascii)!
    
    /**
     Creates a new instance from the given data.
     
     - Parameter data: The compressed distribution.
     */

    public init?(data: Data) {
        self.data = data
        guard let archive = Archive(data: data, accessMode: .read, preferredEncoding: .ascii) else { return nil }
        self.archive = archive
    }
    
    /**
     Decompresses and reads a file from the distribution archive.
     
     - Parameter path: The path to the file within the archive.
     - Parameter eachLine: A callback for each line of text in the expanded
                           file.
     - Parameter data: A line of text from the file being read.
     
     - Throws: `DistributionError.noSuchFile` if a file at `path` doesn't exist
               within the archive.
     */

    public func readFile(path: String, eachLine: (_ data: Data) -> Void) throws {
        guard let entry = archive[path] else { throw DistributionError.noSuchFile(path: path) }
        var buffer = Data(capacity: Int(chunkSize))

        let _ = try archive.extract(entry, bufferSize: chunkSize, skipCRC32: false, progress: nil) { data in
            buffer.append(data)
            while let EOL = buffer.range(of: delimiter) {
                eachLine(buffer.subdata(in: buffer.startIndex..<EOL.lowerBound))
                buffer.removeSubrange(buffer.startIndex..<EOL.upperBound)
            }
        }
        if buffer.count > 0 { eachLine(buffer) }
    }
}
