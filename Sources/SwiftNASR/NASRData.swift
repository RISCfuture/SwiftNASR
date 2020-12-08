import Foundation

/**
 A Codable class containing all data parsed from a NASR distribution. The
 members of this class will be `nil` until their respective calls to
 `SwiftNASR.parse` have been made.
 
 This class can be encoded to disk using an `Encoder` of your choice, retrieved
 later using the corresponding `Decoder`, and re-associated with a `SwiftNASR`
 object using `SwiftNASR.fromData`. Parsing the data takes much longer than
 decoding it, so it is recommended to parse the data only once per cycle, and
 retrieve it using a `Decoder` thereafter.
 */

public class NASRData: Codable {
    
    /// The cycle for the NASR distribution containing this data.
    public var cycle: Cycle?
    
    /// US states and territories.
    public var states: Array<State>? = nil
    
    /// Airports loaded by SwiftNASR.
    public var airports: Array<Airport>? = nil
    
    /// ARTCCs loaded by SwiftNASR.
    public var ARTCCs: Array<ARTCC>? = nil
    
    /// FSSes loaded by SwiftNASR.
    public var FSSes: Array<FSS>? = nil
    
    enum CodingKeys: String, CodingKey {
        case cycle, states, airports, ARTCCs
    }
}
