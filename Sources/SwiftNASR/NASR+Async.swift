import Foundation

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension NASR {
    
    /**
     Asynchronously loads data, either from disk or from the Internet.
     
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     - Returns: `self` once the data is loaded.
     */
    
    public func load(withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }) async throws -> NASR {
        let distribution = try await loader.load(withProgress: progressHandler)
        self.distribution = distribution
        self.data.cycle = try await self.distribution!.readCycle()
        return self
    }
    
    /**
     Parses states from the NASR distribution. Populates `data.states`.
     
     - Note: Parsing errors are ignored. Parsing always continues.
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     - Returns: The parsed states.
     */
    
    public func parseStates(withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }) async throws -> Array<State> {
        try await parse(.states, withProgress: progressHandler) { _ in true }
        return self.data.states!
    }
    
    /**
     Parses airports from the NASR distribution. Populates `data.airports`.
     
     - Note: Parsing errors are ignored. Parsing always continues.
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     - Returns: The parsed airports.
     */
    
    public func parseAirports(withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }, errorHandler: (Swift.Error) -> Bool) async throws -> Array<Airport> {
        try await parse(.airports, withProgress: progressHandler, errorHandler: errorHandler)
        return self.data.airports!
    }
    
    /**
     Parses ARTCCs from the NASR distribution. Populates `data.ARTCCs`.
     
     - Note: Parsing errors are ignored. Parsing always continues.
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     - Returns: The parsed ARTCC records.
     */
    
    public func parseARTCCs(withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }, errorHandler: (Swift.Error) -> Bool) async throws -> Array<ARTCC> {
        try await parse(.ARTCCFacilities, withProgress: progressHandler, errorHandler: errorHandler)
        return self.data.ARTCCs!
    }
    
    /**
     Parses FSSes from the NASR distribution. Populates `data.FSSes`.
     
     - Note: Parsing errors are ignored. Parsing always continues.
     - Parameter progressHandler: A block that receives the Progress object when
                                  the task begins.
     - Parameter progress: A child Progress object you can add to your parent
                           Progress.
     - Returns: The parsed FSS records.
     */
    
    public func parseFSSes(withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }, errorHandler: (Swift.Error) -> Bool) async throws -> Array<FSS> {
        try await parse(.flightServiceStations, withProgress: progressHandler, errorHandler: errorHandler)
        return self.data.FSSes!
    }
    
    /**
     Parses navaids from the NASR distribution. Populates `data.navaids`.
     
     - Note: Parsing errors are ignored. Parsing always continues.
     - Parameter progressHandler: A block that receives the Progress object when
     the task begins.
     - Parameter progress: A child Progress object you can add to your parent
     Progress.
     - Returns: The parsed navaid records.
     */
    
    public func parseNavaids(withProgress progressHandler: @escaping (_ progress: Progress) -> Void = { _ in }, errorHandler: (Swift.Error) -> Bool) async throws -> Array<Navaid> {
        try await parse(.navaids, withProgress: progressHandler, errorHandler: errorHandler)
        return self.data.navaids!
    }
    
    private func parse(_ type: RecordType, withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, errorHandler: (Swift.Error) -> Bool) async throws {
        guard let distribution = self.distribution else {
            throw Error.notYetLoaded
        }
        
        let parser = parserFor(recordType: type)
        try await parser.prepare(distribution: distribution)
        
        let progress = Progress(totalUnitCount: 10)
        progressHandler(progress)
        let parseProgress = Progress(totalUnitCount: 0, parent: progress, pendingUnitCount: 9)
        
        var stream: AsyncThrowingStream<Data, Swift.Error>
        switch type {
        case .states:
                stream = distribution.readFile(path: "State_&_Country_Codes/STATE.txt", withProgress: { progress.addChild($0, withPendingUnitCount: 1) }, returningLines: { parseProgress.totalUnitCount = Int64($0) })
        default:
                stream = distribution.read(type: type, withProgress: { progress.addChild($0, withPendingUnitCount: 1) }, returningLines: { parseProgress.totalUnitCount = Int64($0) })
        }
        
        for try await line in stream {
            do {
                try parser.parse(data: line)
            } catch (let error) {
                let shouldContinue = errorHandler(error)
                if !shouldContinue { break }
            }
            NASR.progressQueue.async { parseProgress.completedUnitCount += 1 }
        }
        
        parser.finish(data: data)
    }
}
