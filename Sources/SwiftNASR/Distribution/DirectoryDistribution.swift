import Foundation
import Combine
import  Dispatch

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
    
    override func readFileSynchronously(path: String, eachLine: (Data, Progress) -> Void) throws {
        let fileURL = location.appendingPathComponent(path)
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: fileURL)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                throw DistributionError.noSuchFile(path: path)
            } else {
                throw error
            }
        }
        var buffer = Data(capacity: chunkSize)
        let filesize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as! NSNumber
        let progress = Progress(totalUnitCount: filesize.int64Value)

        while true {
            if let EOL = buffer.range(of: delimiter) {
                let subdata = buffer.subdata(in: buffer.startIndex..<EOL.lowerBound)
                ConcurrentDistribution.progressQueue.async { progress.completedUnitCount += Int64(subdata.count) }
                eachLine(subdata, progress)
                buffer.removeSubrange(buffer.startIndex..<EOL.upperBound)
            } else {
                let data = handle.readData(ofLength: chunkSize)
                ConcurrentDistribution.progressQueue.async { progress.completedUnitCount += Int64(data.count) }
                guard data.count > 0 else {
                    if buffer.count > 0 { eachLine(buffer, progress) }
                    return
                }
                buffer.append(data)
            }
        }
    }
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public override func readFileAsynchronously(path: String, subject: CurrentValueSubject<Data, Error>) {
        let fileURL = location.appendingPathComponent(path)
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: fileURL)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                subject.send(completion: .failure(DistributionError.noSuchFile(path: path)))
                return
            } else {
                subject.send(completion: .failure(DistributionError.nsError(error)))
                return
            }
        }
        var buffer = Data(capacity: chunkSize)

        while true {
            if let EOL = buffer.range(of: delimiter) {
                subject.send(buffer.subdata(in: buffer.startIndex..<EOL.lowerBound))
                buffer.removeSubrange(buffer.startIndex..<EOL.upperBound)
            } else {
                let data = handle.readData(ofLength: chunkSize)
                guard data.count > 0 else {
                    if buffer.count > 0 { subject.send(buffer) }
                    subject.send(completion: .finished)
                    return
                }
                buffer.append(data)
            }
        }
    }
}
