import Foundation

/**
 A Codable class containing all data parsed from a NASR distribution. The
 members of this class will be `nil` until their respective calls to
 `NASR.parse` have been made.
 
 This class can be encoded to disk using an `Encoder` of your choice, retrieved
 later using the corresponding `Decoder`, and re-associated with a `SwiftNASR`
 object using `NASR.fromData`. Parsing the data takes much longer than decoding
 it, so it is recommended to parse the data only once per cycle, and retrieve it
 using a `Decoder` thereafter.
 
 NASRData is also responsible for providing cross-references between classes.
 For example, the `associatedAirport` property on `FSS` references an `Airport`
 which is part of the same containing `NASRData` instance. Rather than directly
 set a reference between the FSS and the airport (which can create circular
 dependencies), `FSS.associatedAirpßort` is a computed property that uses the
 containing `NASRData` instance to find the associated airport.
 */

public class NASRData: Codable {
    
    /// The cycle for the NASR distribution containing this data.
    public var cycle: Cycle?
    
    /// US states and territories.
    public var states: Array<State>? = nil
    
    /// Airports loaded by SwiftNASR.
    public var airports: Array<Airport>? = nil {
        didSet {
            if let airports = airports {
                for airport in airports {
                    airport.data = self
                    for runway in airport.runways {
                        runway.baseEnd.LAHSO?.findRunwayByID = airport.findRunwayByID()
                        runway.reciprocalEnd?.LAHSO?.findRunwayByID = airport.findRunwayByID()
                    }
                }
            }
        }
    }
    
    /// ARTCCs loaded by SwiftNASR.
    public var ARTCCs: Array<ARTCC>? = nil {
        didSet {
            if let ARTCCs = ARTCCs {
                for ARTCC in ARTCCs {
                    ARTCC.data = self
                    for i in 0..<ARTCC.frequencies.count {
                        ARTCC.frequencies[i].findAirportByID = ARTCC.findAirportByID()
                    }
                }
            }
        }
    }
    
    /// FSSes loaded by SwiftNASR. 
    public var FSSes: Array<FSS>? = nil {
        didSet {
            if let FSSes = FSSes {
                for FSS in FSSes {
                    FSS.data = self
                    for i in 0..<FSS.commFacilities.count {
                        FSS.commFacilities[i].findStateByName = FSS.findStateByName()
                    }
                }
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case cycle, states, airports, ARTCCs, FSSes
    }
    
    init() {  }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let decodedCycle = try container.decodeIfPresent(Cycle.self, forKey: .cycle)
        let decodedStates = try container.decodeIfPresent(Array<State>.self, forKey: .states)
        let decodedAirports = try container.decodeIfPresent(Array<Airport>.self, forKey: .airports)
        let decodedARTCCs = try container.decodeIfPresent(Array<ARTCC>.self, forKey: .ARTCCs)
        let decodedFSSes = try container.decodeIfPresent(Array<FSS>.self, forKey: .FSSes)
        
        // stick these setters in a defer block so that the didSet hooks get called
        defer {
            cycle = decodedCycle
            states = decodedStates
            airports = decodedAirports
            ARTCCs = decodedARTCCs
            FSSes = decodedFSSes
        }
    }
}

/**
 Adds methods to `Airport` for accessing associated objects in the containing
 `NASRData` instance. These methods return `nil` unless the associated data has
 already been loaded.
 */

public extension Airport {
    
    /// The the state the airport is in.
    var state: State? {
        guard let stateCode = stateCode else { return nil }
        guard let states = data?.states else { return nil }
        
        return states.first(where: { $0.postOfficeCode == stateCode })
    }
    
    /// The state containing the associated county.
    var countyState: State? {
        guard let states = data?.states else { return nil }
        
        return states.first(where: { $0.postOfficeCode == countyStateCode })
    }
    
    /// The ARTCC facilities belonging to the ARTCC whose boundaries contain
    /// this airport.
    var boundaryARTCCs: Array<ARTCC>? {
        guard let ARTCCs = data?.ARTCCs else { return nil }
        
        return ARTCCs.filter { $0.ID == boundaryARTCCID }
    }
    
    /// The ARTCC facilities belonging to the ARTCC that is responsible for
    /// traffic departing from and arriving at this airport.
    var responsibleARTCCs: Array<ARTCC>? {
        guard let ARTCCs = data?.ARTCCs else { return nil }
        
        return ARTCCs.filter { $0.ID == responsibleARTCCID }
    }
    
    /// The tie-in flight service station responsible for this airport.
    var tieInFSS: FSS? {
        guard let FSSes = data?.FSSes else { return nil }
        
        return FSSes.first(where: { $0.ID == tieInFSSID })
    }
    
    /// An alternate FSS responsible for this airport when the tie-in FSS is
    /// closed.
    var alternateFSS: FSS? {
        guard let FSSes = data?.FSSes else { return nil }
        guard let alternateFSSID = alternateFSSID else { return nil }
        
        return FSSes.first(where: { $0.ID == alternateFSSID })
    }
    
    /// The FSS responsible for issuing NOTAMs for this airport.
    var NOTAMIssuer: FSS? {
        guard let FSSes = data?.FSSes else { return nil }
        guard let NOTAMIssuerID = NOTAMIssuerID else { return nil }
        
        return FSSes.first(where: { $0.ID == NOTAMIssuerID })
    }
}

extension Airport {
    func findRunwayByID() -> ((_ runwayID: String) -> Runway?) {
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
        guard let stateCode = stateCode else { return nil }
        guard let states = data?.states else { return nil }
        
        return states.first(where: { $0.postOfficeCode == stateCode })
    }
    
    func findAirportByID() -> ((_ airportID: String) -> Airport?) {
        return { airportID in
            guard let airports = self.data?.airports else { return nil }
            
            return airports.first(where: { $0.LID == airportID })
        }
    }
}

public extension ARTCC.CommFrequency {
    
    /// The associated airport, if this facility is associated with an airport.
    var associatedAirport: Airport? {
        guard let associatedAirportCode = associatedAirportCode else { return nil }
        return findAirportByID(associatedAirportCode)
    }
}

public extension FSS {
    
    /// The nearest FSS with teletype capability.
    var nearestFSSWithTeletype: FSS? {
        guard let nearestFSSIDWithTeletype = nearestFSSIDWithTeletype else { return nil }
        guard let FSSes = data?.FSSes else { return nil }
        
        return FSSes.first(where: { $0.ID == nearestFSSIDWithTeletype })
    }
    
    /// The state associated with the FSS, when the FSS is not located on an
    /// airport.
    var state: State? {
        guard let stateName = stateName else { return nil }
        guard let states = data?.states else { return nil }
        
        return states.first(where: { $0.name == stateName })
    }
    
    /// The airport this FSS is associated with, if any.
    var airport: Airport? {
        guard let airportID = airportID else { return nil }
        guard let airports = data?.airports else { return nil }
        
        return airports.first(where: { $0.LID == airportID })
    }
}

extension FSS {
    func findStateByName() -> ((_ name: String) -> State?) {
        return { name in
            guard let states = self.data?.states else { return nil }
            return states.first(where: { $0.name == name })
        }
    }
}

public extension FSS.CommFacility {
    
    /// The state associated with the comm facility.
    var state: State? {
        guard let stateName = stateName else { return nil }
        return findStateByName(stateName)
    }
}
