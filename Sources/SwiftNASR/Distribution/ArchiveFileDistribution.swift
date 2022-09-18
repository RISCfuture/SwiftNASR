import Foundation
import Combine
import ZIPFoundation

/**
 A NASR distribution that has been loaded from a ZIP archive and saved to a
 file. ZIPFoundation is used to extract the archive, which is loaded in buffered
 chunks.
 */

public class ArchiveFileDistribution: ConcurrentDistribution {
    
    /// The compressed distribution file.
    public let location: URL
    
    private let archive: Archive
    
    private var chunkSize = defaultReadChunkSize
    private var delimiter = "\r\n".data(using: .ascii)!
    
    /**
     Creates a new instance from the given file.
     
     - Parameter location: The path to the compressed distribution file.
     */

    public init?(location: URL) {
        self.location = location
        guard let archive = Archive(url: location, accessMode: .read) else { return nil }
        self.archive = archive
    }
    
    @discardableResult func readFileWithCallback(path: String, withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, eachLine: (Data) -> Void) throws -> UInt {
        guard let entry = archive[path] else { throw Error.noSuchFile(path: path) }
        var buffer = Data(capacity: Int(chunkSize))
        var lines: UInt = 0
        
        let progress = Progress(totalUnitCount: Int64(entry.uncompressedSize))
        progressHandler(progress)

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
                
                eachLine(subdata)
                lines += 1
                
                buffer.removeSubrange(subrange)
            }
        }
        if buffer.count > 0 {
            eachLine(buffer)
            lines += 1
        }
        
        return lines
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func readFileWithCombine(path: String, withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, returningLines linesHandler: @escaping (UInt) -> Void = { _ in }, subject: CurrentValueSubject<Data, Swift.Error>) {
        do {
            let lines = try readFileWithCallback(path: path, withProgress: progressHandler) { data in
                subject.send(data)
            }
            linesHandler(lines)
            subject.send(completion: .finished)
        } catch (let error) {
            subject.send(completion: .failure(error))
        }
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func readFileWithAsyncAwait(path: String, withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, returningLines linesHandler: @escaping (UInt) -> Void = { _ in }) -> AsyncThrowingStream<Data, Swift.Error> {
        return AsyncThrowingStream { continuation in
            do {
                let lines = try readFileWithCallback(path: path, withProgress: progressHandler) { data in
                    continuation.yield(data)
                }
                linesHandler(lines)
                continuation.finish()
            } catch (let error) {
                continuation.finish(throwing: error)
            }
        }
    }
}
