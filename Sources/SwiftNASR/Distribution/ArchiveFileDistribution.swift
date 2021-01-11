import Foundation
import Combine
import Dispatch
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
    
    override func readFileSynchronously(path: String, eachLine: (Data, Progress) -> Void) throws {
        guard let entry = archive[path] else { throw DistributionError.noSuchFile(path: path) }
        var buffer = Data(capacity: Int(chunkSize))
        let progress = Progress(totalUnitCount: Int64(entry.uncompressedSize))

        let _ = try archive.extract(entry, bufferSize: chunkSize, skipCRC32: false, progress: nil) { data in
            buffer.append(data)
            ConcurrentDistribution.progressQueue.async { progress.completedUnitCount += Int64(data.count) }
            while let EOL = buffer.range(of: delimiter) {
                eachLine(buffer.subdata(in: buffer.startIndex..<EOL.lowerBound), progress)
                buffer.removeSubrange(buffer.startIndex..<EOL.upperBound)
            }
        }
        if buffer.count > 0 { eachLine(buffer, progress) }
    }
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public override func readFileAsynchronously(path: String, subject: CurrentValueSubject<Data, Error>) {
        guard let entry = archive[path] else {
            subject.send(completion: .failure(DistributionError.noSuchFile(path: path)))
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
