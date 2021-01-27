import Foundation
import Combine
import Dispatch
import ZIPFoundation

/**
 A NASR distribution that has been loaded from a ZIP archive and stored in
 memory. ZIPFoundation is used to extract the archive, which is loaded in
 buffered chunks.
 */

public class ArchiveDataDistribution: ConcurrentDistribution {
    
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
    
    override func readFileSynchronously(path: String, eachLine: (Data, Progress) -> Void) throws {
        guard let entry = archive[path] else { throw Error.noSuchFile(path: path) }
        var buffer = Data(capacity: Int(chunkSize))
        let progress = Progress(totalUnitCount: Int64(entry.uncompressedSize))

        let _ = try archive.extract(entry, bufferSize: chunkSize, skipCRC32: false, progress: nil) { data in
            buffer.append(data)
            Self.progressQueue.async { progress.completedUnitCount += Int64(data.count) }
            while let EOL = buffer.range(of: delimiter) {
                eachLine(buffer.subdata(in: buffer.startIndex..<EOL.lowerBound), progress)
                buffer.removeSubrange(buffer.startIndex..<EOL.upperBound)
            }
        }
        if buffer.count > 0 { eachLine(buffer, progress) }
    }
    
    /**
     Decompresses and reads a file from the distribution archive.
     
     - Parameter path: The path to the file within the archive.
     - Returns: A publisher that publishes each line, in order, from the
                decompressed file.
     */
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public override func readFileAsynchronously(path: String, subject: CurrentValueSubject<Data, Swift.Error>) {
        guard let entry = archive[path] else {
            subject.send(completion: .failure(Error.noSuchFile(path: path)))
            return
        }
                    
        do {
            var buffer = Data(capacity: Int(chunkSize))
            let _ = try archive.extract(entry, bufferSize: chunkSize, skipCRC32: false, progress: nil) { data in
                buffer.append(data)
                while let EOL = buffer.range(of: delimiter) {
                    subject.send(buffer.subdata(in: buffer.startIndex..<EOL.lowerBound))
                    buffer.removeSubrange(buffer.startIndex..<EOL.upperBound)
                }
            }
            if buffer.count > 0 { subject.send(buffer) }
            subject.send(completion: .finished)
        } catch (let error) {
            subject.send(completion: .failure(error))
        }
    }
}
