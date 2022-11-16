import Foundation
import Combine

/**
 An empty distribution, used by ``NullLoader`` to provide API compatibility
 between ``NASR`` instances created for the purpose of downloading NASR data for
 the first time, and instances created from decoded data that was previously
 downloaded and parsed.
 */

public class NullDistribution: Distribution {
    public func findFile(prefix: String) throws -> String? {
        throw Error.nullDistribution
    }
    
    @discardableResult public func readFile(path: String, withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, eachLine: (Data) -> Void) throws -> UInt {
        throw Error.nullDistribution
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func readFilePublisher(path: String, withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, returningLines linesHandler: @escaping (UInt) -> Void = { _ in }) -> AnyPublisher<Data, Swift.Error> {
        return Fail(error: Error.nullDistribution).eraseToAnyPublisher()
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func readFile(path: String, withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, returningLines linesHandler: @escaping (UInt) -> Void = { _ in }) -> AsyncThrowingStream<Data, Swift.Error> {
        return AsyncThrowingStream { $0.finish(throwing: Error.nullDistribution) }
    }
    
    public func readCycle(callback: (_ cycle: Cycle?) -> Void) throws {
        callback(nil)
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func readCyclePublisher() -> AnyPublisher<Cycle?, Error> {
        return Result.Publisher(nil).eraseToAnyPublisher()
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func readCycle() throws -> Cycle? {
        return nil
    }
}
