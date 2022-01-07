import Foundation
import Combine
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
    
    func readFileWithCallback(path: String, eachLine: (Data, Progress) -> Void) throws {
        guard let entry = archive[path] else { throw Error.noSuchFile(path: path) }
        var buffer = Data(capacity: Int(chunkSize))
        let progress = Progress(totalUnitCount: Int64(entry.uncompressedSize))

        let _ = try archive.extract(entry, bufferSize: chunkSize, skipCRC32: false, progress: nil) { data in
            buffer.append(data)
            progressQueue.async { progress.completedUnitCount += Int64(data.count) }
            while let EOL = buffer.range(of: delimiter) {
                if EOL.startIndex == 0 {
                    buffer.removeSubrange(EOL)
                    continue
                }
                
                let subrange = buffer.startIndex..<EOL.lowerBound
                let subdata = buffer.subdata(in: subrange)
                eachLine(subdata, progress)
                buffer.removeSubrange(subrange)
            }
        }
        if buffer.count > 0 { eachLine(buffer, progress) }
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func readFileWithCombine(path: String, subject: CurrentValueSubject<Data, Swift.Error>) {
        do {
            try readFileWithCallback(path: path) { data, progress in
                subject.send(data)
            }
            subject.send(completion: .finished)
        } catch (let error) {
            subject.send(completion: .failure(error))
        }
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func readFileWithAsyncAwait(path: String) -> AsyncThrowingStream<(Data, Progress), Swift.Error> {
        return AsyncThrowingStream { continuation in
            do {
                try readFileWithCallback(path: path) { data, progress in
                    continuation.yield((data, progress))
                }
                continuation.finish()
            } catch (let error) {
                continuation.finish(throwing: error)
            }
        }
    }
}
