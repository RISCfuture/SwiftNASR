import Foundation
import Combine

/**
 A NASR distribution that has been loaded from a directory of decompressed
 archive files.
 */

public class DirectoryDistribution: ConcurrentDistribution {
    
    /// The directory containing the distribution files.
    public let location: URL

    private var chunkSize = 4096
    private var delimiter = "\r\n".data(using: .ascii)!
    
    /**
     Creates a new instance from the given directory.
     
     - Parameter location: The path to the distribution directory.
     */

    public init(location: URL) {
        self.location = location
    }
    
    func readFileWithCallback(path: String, eachLine: (Data, Progress) -> Void) throws {
        let fileURL = location.appendingPathComponent(path)
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: fileURL)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                throw Error.noSuchFile(path: path)
            } else {
                throw error
            }
        }
        var buffer = Data(capacity: chunkSize)
        let filesize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as! NSNumber
        let progress = Progress(totalUnitCount: filesize.int64Value)

        while true {
            if let EOL = buffer.range(of: delimiter) {
                if EOL.lowerBound == 0 {
                    buffer.removeSubrange(EOL)
                    continue
                }
                
                let subrange = buffer.startIndex..<EOL.lowerBound
                let subdata = buffer.subdata(in: subrange)
                progressQueue.async { progress.completedUnitCount += Int64(subdata.count) }
                eachLine(subdata, progress)
                buffer.removeSubrange(subrange)
            } else {
                let data = handle.readData(ofLength: chunkSize)
                progressQueue.async { progress.completedUnitCount += Int64(data.count) }
                guard data.count > 0 else {
                    if buffer.count > 0 { eachLine(buffer, progress) }
                    return
                }
                buffer.append(data)
            }
        }
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
