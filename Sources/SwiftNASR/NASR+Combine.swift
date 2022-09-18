import Foundation
import Combine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension NASR {
    
    /**
     Asynchronously loads data, either from disk or from the Internet.
     
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     - Returns: A publisher that publishes this object when the data is loaded.
     */
    
    public func loadPublisher(withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }) -> AnyPublisher<NASR, Swift.Error> {
        return loader.loadPublisher(withProgress: progressHandler)
            .handleEvents(receiveOutput: { self.distribution = $0 })
            .tryMap { distribution in
                try distribution.readCyclePublisher()
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
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     - Returns: A publisher that publishes the final states array, and any
                errors that occur while parsing. The subscriber can then choose
                whether to unsubscribe from the publisher or let it continue
                parsing, for each published error. Errors published as part of
                the _failure_ state of the publisher are fatal and unrelated to
                parsing.
     */
    
    public func parseStatesPublisher(errorHandler: ((_ error: Swift.Error) -> Void)? = { _ in }, withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }) -> AnyPublisher<Array<State>, Swift.Error> {
        return parsePublisher(.states, errorHandler: errorHandler!, withProgress: progressHandler)
            .map { _ in self.data.states! }.eraseToAnyPublisher()
    }
    
    /**
     Parses airports from the NASR distribution. Populates `data.airports`.
     
     - Parameter errorHandler: A block to call when a parse error is
                               encountered. Parsing will always continue.
     - Parameter error: The parse error.
     - Returns: A publisher that publishes the final airports array, and any
                errors that occur while parsing. The subscriber can then choose
                whether to unsubscribe from the publisher or let it continue
                parsing, for each published error. Errors published as part of
                the _failure_ state of the publisher are fatal and unrelated to
                parsing.
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     */
    
    public func parseAirportsPublisher(errorHandler: ((_ error: Swift.Error) -> Void)? = { _ in }, withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }) -> AnyPublisher<Array<Airport>, Swift.Error> {
        return parsePublisher(.airports, errorHandler: errorHandler!, withProgress: progressHandler)
            .map { _ in self.data.airports! }.eraseToAnyPublisher()
    }
    
    /**
     Parses ARTCCs from the NASR distribution. Populates `data.ARTCCs`.
     
     - Parameter errorHandler: A block to call when a parse error is
                               encountered. Parsing will always continue.
     - Parameter error: The parse error.
     - Returns: A publisher that publishes the final ARTCCs array, and any
                errors that occur while parsing. The subscriber can then choose
                whether to unsubscribe from the publisher or let it continue
                parsing, for each published error. Errors published as part of
                the _failure_ state of the publisher are fatal and unrelated to
                parsing.
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     */
    
    public func parseARTCCsPublisher(errorHandler: ((_ error: Swift.Error) -> Void)? = { _ in }, withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }) -> AnyPublisher<Array<ARTCC>, Swift.Error> {
        return parsePublisher(.ARTCCFacilities, errorHandler: errorHandler!, withProgress: progressHandler)
            .map { _ in self.data.ARTCCs! }.eraseToAnyPublisher()
    }
    
    /**
     Parses FSSes from the NASR distribution. Populates `data.FSSes`.
     
     - Parameter errorHandler: A block to call when a parse error is
                               encountered. Parsing will always continue.
     - Parameter error: The parse error.
     - Returns: A publisher that publishes the final FSSes array, and any
                errors that occur while parsing. The subscriber can then choose
                whether to unsubscribe from the publisher or let it continue
                parsing, for each published error. Errors published as part of
                the _failure_ state of the publisher are fatal and unrelated to
                parsing.
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     */
    
    public func parseFSSesPublisher(errorHandler: ((_ error: Swift.Error) -> Void)? = { _ in }, withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }) -> AnyPublisher<Array<FSS>, Swift.Error> {
        return parsePublisher(.flightServiceStations, errorHandler: errorHandler!, withProgress: progressHandler)
            .map { _ in self.data.FSSes! }.eraseToAnyPublisher()
    }
    
    /**
     Parses navaids from the NASR distribution. Populates `data.navaids`.
     
     - Parameter errorHandler: A block to call when a parse error is
     encountered. Parsing will always continue.
     - Parameter error: The parse error.
     - Returns: A publisher that publishes the final navaids array, and any
     errors that occur while parsing. The subscriber can then choose
     whether to unsubscribe from the publisher or let it continue
     parsing, for each published error. Errors published as part of
     the _failure_ state of the publisher are fatal and unrelated to
     parsing.
     - Parameter progressHandler: A block that receives the Progress object when
     the task begins.
     - Parameter progress: A child Progress object you can add to your parent
     Progress.
     */
    
    public func parseNavaidsPublisher(errorHandler: ((_ error: Swift.Error) -> Void)? = { _ in }, withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }) -> AnyPublisher<Array<Navaid>, Swift.Error> {
        return parsePublisher(.navaids, errorHandler: errorHandler!, withProgress: progressHandler)
            .map { _ in self.data.navaids! }.eraseToAnyPublisher()
    }
    
    private func parsePublisher(_ type: RecordType, errorHandler: @escaping (_ error: Swift.Error) -> Void, withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) -> AnyPublisher<Void, Swift.Error> {
        guard let distribution = self.distribution else {
            return Result.Publisher(Result.failure(Error.notYetLoaded)).eraseToAnyPublisher()
        }
        let parser = parserFor(recordType: type)

        return parser.preparePublisher(distribution: distribution).map { () -> AnyPublisher<Data, Swift.Error> in
            switch type {
                case .states:
                    return distribution.readFilePublisher(path: "State_&_Country_Codes/STATE.txt", withProgress: progressHandler, returningLines: {_ in })
                default: return distribution.readPublisher(type: type, withProgress: progressHandler)
            }
        }.switchToLatest()
            .map { data in
                guard !data.isEmpty else { return } // initial subject value
                do {
                    try parser.parse(data: data)
                } catch (let error) {
                    errorHandler(error)
                }
            }
            .last()
            .map { _ in parser.finish(data: self.data) }
            .eraseToAnyPublisher()
    }
}
