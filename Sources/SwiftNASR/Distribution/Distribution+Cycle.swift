import Foundation
import Combine

extension Distribution {
    private var cycleDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = zulu
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }
    
    private var readmeFirstLine: Data { "AIS subscriber files effective date ".data(using: .ascii)! }
    
    /**
     Reads the cycle from the README file.
     
     - Parameter callback: A function to call with the parsed cycle.
     - Parameter cycle: The parsed cycle, or `nil` if the cycle could not be
                        parsed.
     */
    
    public func readCycle(callback: (_ cycle: Cycle?) -> Void) throws {
        var called = false
        try readFile(path: "README.txt") { line in
            if line.starts(with: readmeFirstLine) {
                callback(parseCycleFrom(line))
                called = true
            }
        }
        
        if !called { callback(nil) }
    }
    
    /**
     Reads the cycle from the README file.
     
     - Returns: A publisher that publishes the parsed cycle, if any.
     */
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func readCycle() -> AnyPublisher<Cycle?, Error> {
        return readFile(path: "README.txt")
            .filter { $0.starts(with: readmeFirstLine) }
            .map { parseCycleFrom($0) }
            .first()
            .eraseToAnyPublisher()
    }
    
    private func parseCycleFrom(_ line: Data) -> Cycle? {
        let cycleDateData = line[readmeFirstLine.count..<(line.count - 1)]
        guard let cycleDateString = String(data: cycleDateData, encoding: .ascii) else {
            return nil
        }
        guard let cycleDate = cycleDateFormatter.date(from: cycleDateString) else {
            return nil
        }
        
        let cycleComponents = Calendar.init(identifier: .gregorian).dateComponents(in: zulu, from: cycleDate)
        guard let year = cycleComponents.year else { return nil }
        guard let month = cycleComponents.month else { return nil }
        guard let day = cycleComponents.day else { return nil }
        
        let cycle = Cycle(year: UInt(year), month: UInt8(month), day: UInt8(day))
        return cycle
    }
}
