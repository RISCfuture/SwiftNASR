import Foundation

/**
 An empty distribution, used by ``NullLoader`` to provide API compatibility
 between ``NASR`` instances created for the purpose of downloading NASR data for
 the first time, and instances created from decoded data that was previously
 downloaded and parsed.
 */

public final class NullDistribution: Distribution {
    public func findFile(prefix: String) throws -> String? {
        throw Error.nullDistribution
    }

    public func readFile(path: String, withProgress progressHandler: @Sendable (Progress) -> Void = { _ in }, returningLines linesHandler: (UInt) -> Void = { _ in }) -> AsyncThrowingStream<Data, Swift.Error> {
        return AsyncThrowingStream { $0.finish(throwing: Error.nullDistribution) }
    }
    
    public func readCycle() throws -> Cycle? {
        return nil
    }
}
