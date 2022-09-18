import Foundation
import Dispatch
import Combine

/**
 Abstract superclass for Distribution subclasses that need to control concurrent
 access to their backing distribution data (e.g., a distribution backed by a
 file on disk).
 */

protocol ConcurrentDistribution: Distribution {
    func readFileWithCallback(path: String, eachLine: (Data, Progress) -> Void) throws
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func readFileWithCombine(path: String, subject: CurrentValueSubject<Data, Swift.Error>)
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func readFileWithAsyncAwait(path: String) -> AsyncThrowingStream<(Data, Progress), Swift.Error>
}

extension ConcurrentDistribution {
    public func readFile(path: String, eachLine: (_ data: Data, _ progress: Progress) -> Void) throws {
        mutex.wait()
        defer { mutex.signal() }
        
        try readFileWithCallback(path: path, eachLine: eachLine)
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func readFilePublisher(path: String) -> AnyPublisher<Data, Swift.Error> {
        let subject = CurrentValueSubject<Data, Swift.Error>(Data())
        
        queue.async { [self] in
            mutex.wait()
            defer { mutex.signal() }
            readFileWithCombine(path: path, subject: subject)
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func readFile(path: String) -> AsyncThrowingStream<(Data, Progress), Swift.Error> {
        mutex.wait()
        defer { mutex.signal() }
        return readFileWithAsyncAwait(path: path)
    }
}

/// The queue that progress updates are processed on. By default, an
/// internal queue at the `userInteractive` QoS level. If you have a main
/// thread where progress updates must be made, then set this var to that
/// thread.
public var progressQueue = DispatchQueue(label: "codes.tim.SwiftNASR.ConcurrentDistribution.progress", qos: .userInteractive)

fileprivate let queue = DispatchQueue(label: "codes.tim.SwiftNASR.ConcurrentDistribution", qos: .utility, attributes: [], autoreleaseFrequency: .workItem)
fileprivate let mutex = DispatchSemaphore(value: 1)

