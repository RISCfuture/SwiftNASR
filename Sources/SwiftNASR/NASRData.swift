import Foundation

/**
 A data class containing all data parsed from a NASR distribution. The
 members of this class will be `nil` until their respective calls to
 ``NASR/parse(_:withProgress:errorHandler:)`` have been made.
 
 This class can be encoded to disk using ``NASRDataCodable``, and re-associated
 with a SwiftNASR object using ``NASR/fromData(_:)``. Parsing the data takes
 much longer than decoding it, so it is recommended to parse the data only once
 per cycle, and retrieve it using a `Decoder` thereafter.

 To encode a `NASRData` instance, create a new `NASRDataCodable` instance using
 ``NASRDataCodable/init(data:)``, and then encode it using your `Encoder` of
 choice. To decode your data, use ``NASRDataCodable/init(from:)``, and then
 convert it to a `NASRData` instance using ``NASRDataCodable/makeData()``.

 NASRData is also responsible for providing cross-references between classes.
 For example, the ``FSS/airport`` property references an ``Airport``
 which is part of the same containing ``NASRData`` instance. Rather than
 directly set a reference between the FSS and the airport (which can create
 circular dependencies), ``FSS/airport`` is a computed property that uses the
 containing ``NASRData`` instance to find the associated airport.
 */

public actor NASRData {
    
    /// The cycle for the NASR distribution containing this data.
    public var cycle: Cycle?
    
    /// US states and territories.
    public var states: Array<State>? = nil
    
    /// Airports loaded by SwiftNASR.
    public var airports: Array<Airport>? = nil {
        didSet {
            guard airports != nil else { return }
            for airportID in 0..<airports!.count {
                airports![airportID].data = self
                let findRunwayByID = airports![airportID].findRunwayByID()
                for runwayIndex in 0..<airports![airportID].runways.count {
                    airports![airportID].runways[runwayIndex].baseEnd.LAHSO?.findRunwayByID = findRunwayByID
                    airports![airportID].runways[runwayIndex].reciprocalEnd?.LAHSO?.findRunwayByID = findRunwayByID
                }
            }
        }
    }
    
    /// ARTCCs loaded by SwiftNASR.
    public var ARTCCs: Array<ARTCC>? = nil {
        didSet {
            guard ARTCCs != nil else { return }
            for ARTCCIndex in 0..<ARTCCs!.count {
                ARTCCs![ARTCCIndex].data = self
                let findRunwayByID = ARTCCs![ARTCCIndex].findAirportByID()
                for freqIndex in 0..<ARTCCs![ARTCCIndex].frequencies.count {
                    ARTCCs![ARTCCIndex].frequencies[freqIndex].findAirportByID = findRunwayByID
                }
            }
        }
    }
    
    /// FSSes loaded by SwiftNASR. 
    public var FSSes: Array<FSS>? = nil {
        didSet {
            guard FSSes != nil else { return }
            for FSSIndex in 0..<FSSes!.count {
                FSSes![FSSIndex].data = self
                let findStateByName = FSSes![FSSIndex].findStateByName()
                for facilityIndex in 0..<FSSes![FSSIndex].commFacilities.count {
                    FSSes![FSSIndex].commFacilities[facilityIndex].findStateByName = findStateByName
                }
            }
        }
    }
    
    /// Navaids loaded by SwiftNASR.
    public var navaids: Array<Navaid>? = nil {
        didSet {
            guard navaids != nil else { return }
            for navaidIndex in 0..<navaids!.count {
                navaids![navaidIndex].data = self
                let findStateByCode = navaids![navaidIndex].findStateByCode()
                for checkpointIndex in 0..<navaids![navaidIndex].checkpoints.count {
                    navaids![navaidIndex].checkpoints[checkpointIndex].findStateByCode = findStateByCode
                }
            }
        }
    }
    
    func finishParsing(cycle: Cycle? = nil,
                       states: Array<State>? = nil,
                       airports: Array<Airport>? = nil,
                       ARTCCs: Array<ARTCC>? = nil,
                       FSSes: Array<FSS>? = nil,
                       navaids: Array<Navaid>? = nil) {
        if let cycle { self.cycle = cycle }
        if let states { self.states = states }
        if let airports { self.airports = airports }
        if let ARTCCs { self.ARTCCs = ARTCCs }
        if let FSSes { self.FSSes = FSSes }
        if let navaids { self.navaids = navaids }
    }
}

public extension Airport {
    
    /// The the state the airport is in.
    var state: State? {
        get async {
            guard let stateCode = stateCode else { return nil }
            guard let states = await data?.states else { return nil }

            return states.first(where: { $0.postOfficeCode == stateCode })
        }
    }
    
    /// The state containing the associated county.
    var countyState: State? {
        get async {
            guard let states = await data?.states else { return nil }
            return states.first(where: { $0.postOfficeCode == countyStateCode })
        }
    }
    
    /// The ARTCC facilities belonging to the ARTCC whose boundaries contain
    /// this airport.
    var boundaryARTCCs: Array<ARTCC>? {
        get async {
            guard let ARTCCs = await data?.ARTCCs else { return nil }
            return ARTCCs.filter { $0.ID == boundaryARTCCID }
        }
    }
    
    /// The ARTCC facilities belonging to the ARTCC that is responsible for
    /// traffic departing from and arriving at this airport.
    var responsibleARTCCs: Array<ARTCC>? {
        get async {
            guard let ARTCCs = await data?.ARTCCs else { return nil }
            return ARTCCs.filter { $0.ID == responsibleARTCCID }
        }
    }
    
    /// The tie-in flight service station responsible for this airport.
    var tieInFSS: FSS? {
        get async {
            guard let FSSes = await data?.FSSes else { return nil }
            return FSSes.first(where: { $0.ID == tieInFSSID })
        }
    }
    
    /// An alternate FSS responsible for this airport when the tie-in FSS is
    /// closed.
    var alternateFSS: FSS? {
        get async {
            guard let FSSes = await data?.FSSes else { return nil }
            guard let alternateFSSID = alternateFSSID else { return nil }

            return FSSes.first(where: { $0.ID == alternateFSSID })
        }
    }
    
    /// The FSS responsible for issuing NOTAMs for this airport.
    var NOTAMIssuer: FSS? {
        get async {
            guard let FSSes = await data?.FSSes else { return nil }
            guard let NOTAMIssuerID = NOTAMIssuerID else { return nil }

            return FSSes.first(where: { $0.ID == NOTAMIssuerID })
        }
    }
}

extension Airport {
    func findRunwayByID() -> (@Sendable (_ runwayID: String) -> Runway?) {
        return { runwayID in
            return self.runways.first(where: { $0.identification == runwayID })
        }
    }
}

public extension RunwayEnd.LAHSOPoint {
    
    /// The intersecting runway defining the LAHSO point, if defined by runway.
    var intersectingRunway: Runway? {
        guard let intersectingRunwayID = intersectingRunwayID else { return nil }
        return findRunwayByID(intersectingRunwayID)
    }
}

extension ARTCC {
    
    /// The state containing the Center facility.
    public var state: State? {
        get async {
            guard let stateCode = stateCode else { return nil }
            guard let states = await data?.states else { return nil }

            return states.first(where: { $0.postOfficeCode == stateCode })
        }
    }
    
    func findAirportByID() -> (@Sendable (_ airportID: String) async -> Airport?) {
        return { airportID in
            guard let airports = await self.data?.airports else { return nil }

            return airports.first(where: { $0.LID == airportID })
        }
    }
}

public extension ARTCC.CommFrequency {
    
    /// The associated airport, if this facility is associated with an airport.
    var associatedAirport: Airport? {
        get async {
            guard let associatedAirportCode = associatedAirportCode else { return nil }
            return await findAirportByID(associatedAirportCode)
        }
    }
}

public extension FSS {
    
    /// The nearest FSS with teletype capability.
    var nearestFSSWithTeletype: FSS? {
        get async {
            guard let nearestFSSIDWithTeletype = nearestFSSIDWithTeletype else { return nil }
            guard let FSSes = await data?.FSSes else { return nil }

            return FSSes.first(where: { $0.ID == nearestFSSIDWithTeletype })
        }
    }
    
    /// The state associated with the FSS, when the FSS is not located on an
    /// airport.
    var state: State? {
        get async {
            guard let stateName = stateName else { return nil }
            guard let states = await data?.states else { return nil }

            return states.first(where: { $0.name == stateName })
        }
    }
    
    /// The airport this FSS is associated with, if any.
    var airport: Airport? {
        get async {
            guard let airportID = airportID else { return nil }
            guard let airports = await data?.airports else { return nil }

            return airports.first(where: { $0.LID == airportID })
        }
    }
}

extension FSS {
    func findStateByName() -> (@Sendable (_ name: String) async -> State?) {
        return { name in
            guard let states = await self.data?.states else { return nil }
            return states.first(where: { $0.name == name })
        }
    }
}

public extension FSS.CommFacility {
    
    /// The state associated with the comm facility.
    var state: State? {
        get async {
            guard let stateName = stateName else { return nil }
            return await findStateByName(stateName)
        }
    }
}

extension Navaid {
    func findAirportByID() -> (@Sendable (_ airportID: String) async -> Airport?) {
        return { airportID in
            guard let airports = await self.data?.airports else { return nil }

            return airports.first(where: { $0.LID == airportID })
        }
    }
    
    func findStateByCode() -> (@Sendable (_ code: String) async -> State?) {
        return { code in
            guard let states = await self.data?.states else { return nil }
            return states.first(where: { $0.postOfficeCode == code })
        }
    }
}

public extension Navaid {
    
    /// The state associated with the navaid.
    var state: State? {
        get async {
            await data?.states?.first(where: { $0.name == stateName })
        }
    }
    
    /// The high-altitude ARTCC containing this navaid.
    var highAltitudeARTCC: ARTCC? {
        get async {
            guard let highAltitudeARTCCCode = highAltitudeARTCCCode else { return nil }
            return await data?.ARTCCs?.first(where: { $0.ID == highAltitudeARTCCCode })
        }
    }
    
    /// The low-altitude ARTCC containing this navaid.
    var lowAltitudeARTCC: ARTCC? {
        get async {
            guard let lowAltitudeARTCCCode = lowAltitudeARTCCCode else { return nil }
            return await data?.ARTCCs?.first(where: { $0.ID == lowAltitudeARTCCCode })
        }
    }
    
    /// The FSS that controls this navaid.
    var controllingFSS: FSS? {
        get async {
            guard let controllingFSSCode = controllingFSSCode else { return nil }
            return await data?.FSSes?.first(where: { $0.ID == controllingFSSCode })
        }
    }
}

public extension VORCheckpoint {
    
    /// The state associated with the checkpoint.
    var state: State? {
        get async {
            return await findStateByCode(stateCode)
        }
    }
    
    /// The associated airport, if this facility is associated with an airport.
    var airport: Airport? {
        get async {
            guard let airportID = airportID else { return nil }
            return await findAirportByID(airportID)
        }
    }
}

/**
 Because actors cannot yet conform to `Codable`, use this class to encode and
 decode ``NASRData`` instances. See the `NASRData` documentation for information
 on how to encode and decode instances.
 */

public struct NASRDataCodable: Codable {
    var cycle: Cycle?
    var states: Array<State>?
    var airports: Array<Airport>?
    var ARTCCs: Array<ARTCC>?
    var FSSes: Array<FSS>?
    var navaids: Array<Navaid>?

    enum CodingKeys: String, CodingKey {
        case cycle, states, airports, ARTCCs, FSSes, navaids
    }

    public init(data: NASRData) async {
        cycle = await data.cycle
        states = await data.states?.sorted(by: { $0.postOfficeCode < $1.postOfficeCode })
        airports = await data.airports?.sorted(by: { $0.id < $1.id })
        ARTCCs = await data.ARTCCs?.sorted(by: { $0.id < $1.id })
        FSSes = await data.FSSes?.sorted(by: { $0.id < $1.id })
        navaids = await data.navaids?.sorted(by: { $0.id < $1.id })
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedCycle = try container.decodeIfPresent(Cycle.self, forKey: .cycle)
        let decodedStates = try container.decodeIfPresent(Array<State>.self, forKey: .states)
        let decodedAirports = try container.decodeIfPresent(Array<Airport>.self, forKey: .airports)
        let decodedARTCCs = try container.decodeIfPresent(Array<ARTCC>.self, forKey: .ARTCCs)
        let decodedFSSes = try container.decodeIfPresent(Array<FSS>.self, forKey: .FSSes)
        let decodedNavaids = try container.decodeIfPresent(Array<Navaid>.self, forKey: .navaids)

        // stick these setters in a defer block so that the didSet hooks get called
        defer {
            cycle = decodedCycle
            states = decodedStates
            airports = decodedAirports
            ARTCCs = decodedARTCCs
            FSSes = decodedFSSes
            navaids = decodedNavaids
        }
    }

    public func makeData() async -> NASRData {
        let data = NASRData()
        await data.finishParsing(cycle: cycle, states: states, airports: airports, ARTCCs: ARTCCs, FSSes: FSSes)
        return data
    }
}
