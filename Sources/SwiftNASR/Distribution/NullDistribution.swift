import Foundation

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
