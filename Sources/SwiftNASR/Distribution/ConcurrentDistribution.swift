import Foundation
import Dispatch
import Combine

/**
 Abstract superclass for Distribution subclasses that need to control concurrent
 access to their backing distribution data (e.g., a distribution backed by a
 file on disk).
 */

public class ConcurrentDistribution: Distribution {
    private let queue = DispatchQueue(label: "SwiftNASR.ArchiveFileDistribution", qos: .utility, attributes: [], autoreleaseFrequency: .workItem)
    private let mutex = DispatchSemaphore(value: 1)
    
    /**
     Decompresses and reads a file from the distribution.
     
     - Parameter path: The path to the file.
     - Parameter eachLine: A callback for each line of text in the file.
     - Parameter data: A line of text from the file being read.
     
     - Throws: `DistributionError.noSuchFile` if a file at `path` doesn't exist
               within the distribution.
     */
    
    public func readFile(path: String, eachLine: (Data) -> Void) throws {
        mutex.wait()
        defer { mutex.signal() }
        
        try readFileSynchronously(path: path, eachLine: eachLine)
    }
    
    /**
     Decompresses and reads a file from the distribution.
     
     - Parameter path: The path to the file.
     - Returns: A publisher that publishes each line, in order, from the file.
     */
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func readFile(path: String) -> AnyPublisher<Data, Error> {
        let subject = CurrentValueSubject<Data, Error>(Data())

        queue.async { [self] in
            mutex.wait()
            defer { mutex.signal() }
            readFileAsynchronously(path: path, subject: subject)
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    func readFileSynchronously(path: String, eachLine: (Data) -> Void) throws {
        fatalError("Must be implemented by subclasses")
    }
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func readFileAsynchronously(path: String, subject: CurrentValueSubject<Data, Error>) {
        fatalError("Must be implemented by subclasses")
    }
}
