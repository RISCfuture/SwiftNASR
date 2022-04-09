import Foundation

/// Errors that can occur in SwiftNASR methods.
public enum Error: Swift.Error, LocalizedError {
    /// Tried to call `load` on a `SwiftNASR` instance with a null
    /// distribution.
    case nullDistribution
    
    /**
     Received a bad HTTP response.
     
     - Parameter response: The HTTP response.
     */
    case badResponse(_ response: URLResponse)
    
    /// Downloaded tempfile unexpectedly missing.
    case noFile
    
    case noSuchFile(path: String)
    
    /// Response did not contain any body.
    case noData
    
    /// Response body was not parseable.
    case badData
    
    /// `parse` was called before `load`.
    case notYetLoaded
    
    /**
     Parsed an unknown runway surface identifier.
     
     - Parameter value: The unknown identifier.
     */
    case invalidRunwaySurface(_ value: String)
    
    /**
     Parsed an unknown pavement classification identifier.
     
     - Parameter value: The unknown identifier.
     */
    case invalidPavementClassification(_ value: String)
    
    /**
     Parsed an unknown VGSI identifier.
     
     - Parameter value: The unknown identifier.
     */
    case invalidVGSI(_ value: String)
    
    /**
     Parsed an unknown ARTCC identifier.
     
     - Parameter ID: The unknown identifier.
     */
    case unknownARTCC(_ ID: String)
    
    /**
     Parsed an ARTCC frequency record for a frequency not associated with the
     ARTCC.
     
     - Parameter frequency: The unknown frequency.
     - Parameter ARTCC: The ARTCC record.
     */
    case unknownARTCCFrequency(_ frequency: UInt, ARTCC: ARTCC)
    
    /***
     Parsed an unknown navigation aid.
     
     - Parameter ID: The unknown identifier.
     */
    case unknownNavaid(_ ID: String)
    
    /**
     Parsed an unknown ARTCC data field identifier.
     
     - Parameter fieldID: The unknown identifier.
     - Parameter ARTCC: The ARTCC record.
     */
    case unknownFieldID(_ fieldID: String, ARTCC: ARTCC)
    
    /**
     Parsed an unknown ARTCC frequency data field identifier.
     
     - Parameter fieldID: The unknown identifier.
     - Parameter frequency: The associated frequency.
     - Parameter ARTCC: The ARTCC record.
     */
    case unknownFrequencyFieldID(_ fieldID: String, frequency: ARTCC.CommFrequency, ARTCC: ARTCC)
    
    /**
     Attempted to parse an invalid frequency.
     
     - Parameter string: The invalid frequency string.
     */
    case invalidFrequency(_ string: String)
    
    /**
     Attempted to parse data for an unknown FSS ID.
     
     - Parameter string: The unknown FSS ID.
     */
    case unknownFSS(_ ID: String)
    
    public var errorDescription: String? {
        switch self {
            case .nullDistribution:
                return NSLocalizedString("Called .load() on a null distribution.", comment: "SwiftNASR error")
            case let .badResponse(response):
                return String(format: NSLocalizedString("Bad response: %@.", comment: "SwiftNASR error"), response.description)
            case .noFile:
                return NSLocalizedString("Couldn’t find file to load.", comment: "SwiftNASR error")
            case .noData:
                return NSLocalizedString("No data was downloaded.", comment: "SwiftNASR error")
            case .badData:
                return NSLocalizedString("Data is invalid.", comment: "SwiftNASR error")
            case let .unknownARTCC(ID):
                return String(format: NSLocalizedString("Referenced undefined ARTCC record with ID ‘%@’.", comment: "SwiftNASR error"), ID)
            case let .unknownARTCCFrequency(frequency, ARTCC):
                return String(format: NSLocalizedString("Referenced undefined frequency ‘%@’ for ARTCC %@.", comment: "SwiftNASR error"), frequency, ARTCC.ID)
            case let .unknownFieldID(fieldID, ARTCC):
                return String(format: NSLocalizedString("Unknown field ID ‘%@’ at ‘%@ %@’.", comment: "SwiftNASR error"), fieldID, ARTCC.ID, ARTCC.locationName)
            case let .unknownFrequencyFieldID(fieldID, frequency, ARTCC):
                return String(format: NSLocalizedString("Unknown field ID ‘%@’ for %@ kHz at ‘%@ %@’.", comment: "SwiftNASR error"), fieldID, frequency.frequency, ARTCC.ID, ARTCC.locationName)
            case let .invalidFrequency(string):
                return String(format: NSLocalizedString("Invalid frequency ‘%@’.", comment: "SwiftNASR error"), string)
            case let .unknownFSS(ID):
                return String(format: NSLocalizedString("Continuation record references unknown FSS ‘%@’.", comment: "SwiftNASR error"), ID)
            case .notYetLoaded:
                return NSLocalizedString("This NASR has not been loaded yet.", comment: "SwiftNASR error")
            case let .noSuchFile(path):
                return String(format: NSLocalizedString("No such file in distribution: %@.", comment: "SwiftNASR error"), path)
            case let .invalidRunwaySurface(string):
                return String(format: NSLocalizedString("Unknown runway surface ‘%@’.", comment: "SwiftNASR error"), string)
            case let .invalidPavementClassification(string):
                return String(format: NSLocalizedString("Unknown pavement classification ‘%@’ for PCN.", comment: "SwiftNASR error"), string)
            case let .invalidVGSI(string):
                return String(format: NSLocalizedString("Unknown VGSI identifier ‘%@’.", comment: "SwiftNASR error"), string)
            case let .unknownNavaid(string):
                return String(format: NSLocalizedString("Unknown navaid ‘%@’.", comment: "SwiftNASR error"), string)
        }
    }
}
