import Foundation

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NASR {
    public func load(progress: inout Progress) async throws -> NASR {
        self.distribution = try await loader.load(progress: &progress)
        self.data.cycle = try await self.distribution!.readCycle()
        return self
    }
    
    public func parseStates() async throws -> Array<State> {
        try await parse(.states) { _ in true }
        return self.data.states!
    }
    
    public func parseAirports(errorHandler: (Swift.Error) -> Bool) async throws -> Array<Airport> {
        try await parse(.airports, errorHandler: errorHandler)
        return self.data.airports!
    }
    
    public func parseARTCCs(errorHandler: (Swift.Error) -> Bool) async throws -> Array<ARTCC> {
        try await parse(.ARTCCFacilities, errorHandler: errorHandler)
        return self.data.ARTCCs!
    }
    
    public func parseFSSes(errorHandler: (Swift.Error) -> Bool) async throws -> Array<FSS> {
        try await parse(.flightServiceStations, errorHandler: errorHandler)
        return self.data.FSSes!
    }
    
    private func parse(_ type: RecordType, errorHandler: (Swift.Error) -> Bool) async throws {
        guard let distribution = self.distribution else {
            throw Error.notYetLoaded
        }
        
        let parser = parserFor(recordType: type)
        try await parser.prepare(distribution: distribution)
        
        var stream: AsyncThrowingStream<(Data, Progress), Swift.Error>
        switch type {
        case .states:
            stream = distribution.readFile(path: "State_&_Country_Codes/STATE.txt")
        default:
            stream = distribution.read(type: type)
        }
        
        for try await (line, _) in stream {
            do {
                try parser.parse(data: line)
            } catch (let error) {
                let shouldContinue = errorHandler(error)
                if !shouldContinue { break }
            }
        }
        
        parser.finish(data: data)
    }
}
