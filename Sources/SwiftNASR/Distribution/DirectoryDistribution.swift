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
    
    public func findFile(prefix: String) throws -> String? {
        let children = try FileManager.default.contentsOfDirectory(at: location, includingPropertiesForKeys: [.nameKey])
        return children.first(where: { $0.lastPathComponent.hasPrefix(prefix) })?.lastPathComponent
    }
    
    @discardableResult func readFileWithCallback(path: String, withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, eachLine: (Data) -> Void) throws -> UInt {
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
                NASR.progressQueue.async { progress.completedUnitCount += Int64(subdata.count) }
                
                eachLine(subdata)
                lines += 1
                
                buffer.removeSubrange(subrange)
            } else {
                let data = handle.readData(ofLength: chunkSize)
                NASR.progressQueue.async { progress.completedUnitCount += Int64(data.count) }
                guard data.count > 0 else {
                    if buffer.count > 0 {
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
