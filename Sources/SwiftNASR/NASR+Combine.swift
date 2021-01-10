import Foundation
import Combine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension NASR {
    
    /**
     Asynchronously loads data, either from disk or from the Internet.
     
     - Returns: A publisher that publishes this object when the data is loaded.
     */
    
    public func load() -> AnyPublisher<NASR, Swift.Error> {
        return loader.load()
            .handleEvents(receiveOutput: { self.distribution = $0 })
            .map { distribution in
                distribution.readCycle()
                    .handleEvents(receiveOutput: { cycle in self.data.cycle = cycle })
            }
            .switchToLatest()
            .map { _ in self }
            .eraseToAnyPublisher()
    }
    
    /**
     Parses states from the NASR distribution. Populates `data.states`.
     
     - Parameter errorHandler: A block to call when a parse error is
                               encountered. Parsing will always continue.
     - Parameter error: The parse error.
     - Returns: A publisher that publishes the final states array, and any
                errors that occur while states. The subscriber can then choose
                whether to unsubscribe from the publisher or let it continue
                parsing, for each published error. Errors published as part of
                the _failure_ state of the publisher are fatal and unrelated to
                parsing.
     */
    
    public func parseStates(errorHandler: ((_ error: Swift.Error) -> Void)? = { _ in }) -> AnyPublisher<Array<State>, Swift.Error> {
        return parsePublisher(.states, errorHandler: errorHandler!)
            .map { _ in self.data.states! }.eraseToAnyPublisher()
    }
    
    /**
     Parses airports from the NASR distribution. Populates `data.airports`.
     
     - Parameter errorHandler: A block to call when a parse error is
                               encountered. Parsing will always continue.
     - Parameter error: The parse error.
     - Returns: A publisher that publishes the final airports array, and any
                errors that occur while airports. The subscriber can then choose
                whether to unsubscribe from the publisher or let it continue
                parsing, for each published error. Errors published as part of
                the _failure_ state of the publisher are fatal and unrelated to
                parsing.
     */
    
    public func parseAirports(errorHandler: ((_ error: Swift.Error) -> Void)? = { _ in }) -> AnyPublisher<Array<Airport>, Swift.Error> {
        return parsePublisher(.airports, errorHandler: errorHandler!)
            .map { _ in self.data.airports! }.eraseToAnyPublisher()
    }
    
    /**
     Parses ARTCCs from the NASR distribution. Populates `data.ARTCCs`.
     
     - Parameter errorHandler: A block to call when a parse error is
                               encountered. Parsing will always continue.
     - Parameter error: The parse error.
     - Returns: A publisher that publishes the final ARTCCs array, and any
                errors that occur while ARTCCs. The subscriber can then choose
                whether to unsubscribe from the publisher or let it continue
                parsing, for each published error. Errors published as part of
                the _failure_ state of the publisher are fatal and unrelated to
                parsing.
     */
    
    public func parseARTCCs(errorHandler: ((_ error: Swift.Error) -> Void)? = { _ in }) -> AnyPublisher<Array<ARTCC>, Swift.Error> {
        return parsePublisher(.ARTCCFacilities, errorHandler: errorHandler!)
            .map { _ in self.data.ARTCCs! }.eraseToAnyPublisher()
    }
    
    /**
     Parses airports from the NASR distribution. Populates `data.airports`.
     
     - Parameter errorHandler: A block to call when a parse error is
                               encountered. Parsing will always continue.
     - Parameter error: The parse error.
     - Returns: A publisher that publishes the final airports array, and any
                errors that occur while airports. The subscriber can then choose
                whether to unsubscribe from the publisher or let it continue
                parsing, for each published error. Errors published as part of
                the _failure_ state of the publisher are fatal and unrelated to
                parsing.
     */
    
    public func parseFSSes(errorHandler: ((_ error: Swift.Error) -> Void)? = { _ in }) -> AnyPublisher<Array<FSS>, Swift.Error> {
        return parsePublisher(.flightServiceStations, errorHandler: errorHandler!)
            .map { _ in self.data.FSSes! }.eraseToAnyPublisher()
    }
    
    private func parsePublisher(_ type: RecordType,
                      errorHandler: @escaping (_ error: Swift.Error) -> Void) -> AnyPublisher<Void, Swift.Error> {
        guard let distribution = self.distribution else {
            return Result.Publisher(Result.failure(Error.notYetLoaded)).eraseToAnyPublisher()
        }
        let parser = parserFor(recordType: type)
        let queue = DispatchQueue(label: "codes.tim.SwiftNASR.NASR", qos: .utility, attributes: [], autoreleaseFrequency: .workItem)
        
        return parser.preparePublisher(distribution: distribution).map { () -> AnyPublisher<Data, Swift.Error> in
            switch type {
                case .states:
                    return distribution.readFile(path: "State_&_Country_Codes/STATE.txt")
                default:
                    return distribution.read(type: type)
            }
        }.switchToLatest()
        .map { data in
            queue.async {
                guard !data.isEmpty else { return } // initial subject value
                do {
                    try parser.parse(data: data)
                } catch (let error) {
                    errorHandler(error)
                }
            }
        }
        .last()
        .map { _ in parser.finish(data: self.data) }
        .eraseToAnyPublisher()
    }
}
