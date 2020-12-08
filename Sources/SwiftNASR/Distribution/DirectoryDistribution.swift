import Foundation

/**
 A NASR distribution that has been loaded from a directory of decompressed
 archive files.
 */

public class DirectoryDistribution: Distribution {
    
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
    
    /**
     Reads a file from the distribution directory.
     
     - Parameter path: The path to the file within the directory.
     - Parameter eachLine: A callback for each line of text in the file.
     - Parameter data: A line of text from the file being read.
     
     - Throws: `DistributionError.noSuchFile` if a file at `path` doesn't exist
               within the archive.
     */

    public func readFile(path: String, eachLine: (_ data: Data) -> Void) throws {
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

        while true {
            if let EOL = buffer.range(of: delimiter) {
                eachLine(buffer.subdata(in: buffer.startIndex..<EOL.lowerBound))
                buffer.removeSubrange(buffer.startIndex..<EOL.upperBound)
            } else {
                let data = handle.readData(ofLength: chunkSize)
                guard data.count > 0 else {
                    if buffer.count > 0 { eachLine(buffer) }
                    return
                }
                buffer.append(data)
            }
        }
    }
}
