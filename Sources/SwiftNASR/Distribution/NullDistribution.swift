import Foundation
import Combine

/**
 An empty distribution, used by `NullLoader` to provide API compatibility
 between `SwiftNASR` instances created for the purpose of downloading NASR data
 for the first time, and instances created from decoded data that was previously
 downloaded and parsed.
 */

public class NullDistribution: Distribution {
    public func readFile(path: String, eachLine: (Data) -> Void) throws {
        throw Error.nullDistribution
    }
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func readFile(path: String) -> AnyPublisher<Data, Swift.Error> {
        return Fail(error: Error.nullDistribution).eraseToAnyPublisher()
    }
    
    public func readCycle(callback: (_ cycle: Cycle?) -> Void) throws {
        callback(nil)
    }
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func readCycle() -> AnyPublisher<Cycle?, Error> {
        return Result.Publisher(nil).eraseToAnyPublisher()
    }
    
    /// Null distribution errors.
    public enum Error: Swift.Error {
        
        /// Tried to call `load` on a `SwiftNASR` instance with a null
        /// distribution.
        case nullDistribution
        
        public var description: String {
            switch self {
                case .nullDistribution:
                    return "Called .load() on a null distribution"
            }
        }

    }
}
