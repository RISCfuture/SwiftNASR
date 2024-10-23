import Foundation

/// Errors that can occur in SwiftNASR methods.
public enum Error: Swift.Error {
    /// Tried to call ``NASR/load(withProgress:)`` on a ``NASR`` instance with
    /// a ``NullDistribution``.
    case nullDistribution
    
    /**
     Received a bad HTTP response.
     
     - Parameter response: The HTTP response.
     */
    case badResponse(_ response: URLResponse)

    /// No file in distribution archive.
    case noSuchFile(path: String)
    
    /// No such file by prefix in distribution archive.
    case noSuchFilePrefix(_ prefix: String)
    
    /// Response did not contain any body.
    case noData
    
    /// ``NASR/parse(_:withProgress:errorHandler:)`` was called before
    /// ``NASR/load(withProgress:)``.
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
}

extension Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .nullDistribution, .noSuchFilePrefix, .noSuchFile:
                return String(localized: "Couldn’t load distribution.", comment: "error description")
            case .badResponse, .noData:
                return String(localized: "Couldn’t download distribution.", comment: "error description")
            case .unknownARTCC, .unknownARTCCFrequency, .unknownFieldID,
                    .unknownFrequencyFieldID, .invalidFrequency, .unknownFSS,
                    .invalidRunwaySurface, .invalidPavementClassification,
                    .invalidVGSI, .unknownNavaid:
                return String(localized: "Couldn’t parse distribution data.", comment: "error description")
            case .notYetLoaded:
                return String(localized: "This NASR has not been loaded yet.", comment: "error description")
        }
    }
    
    public var failureReason: String? {
        switch self {
            case .nullDistribution:
                return String(localized: "Called .load() on a null distribution.", comment: "failure reason")
            case let .badResponse(response):
                return String(localized: "Bad response: \(response.description).", comment: "failure reason")
            case let .noSuchFilePrefix(prefix):
                return String(localized: "Couldn’t find file in archive with prefix “\(prefix).”", comment: "failure reason")
            case .noData:
                return String(localized: "No data was downloaded.", comment: "failure reason")
            case let .unknownARTCC(ID):
                return String(localized: "Referenced undefined ARTCC record with ID ‘\(ID)’.", comment: "failure reason")
            case let .unknownARTCCFrequency(frequency, ARTCC):
                return String(localized: "Referenced undefined frequency ‘\(frequency)’ for ARTCC \(ARTCC.ID).", comment: "failure reason")
            case let .unknownFieldID(fieldID, ARTCC):
                return String(localized: "Unknown field ID ‘\(fieldID)’ at ‘\(ARTCC.ID) \(ARTCC.locationName)’.", comment: "failure reason")
            case let .unknownFrequencyFieldID(fieldID, frequency, ARTCC):
                return String(localized: "Unknown field ID ‘\(fieldID)’ for \(frequency.frequency) kHz at ‘\(ARTCC.ID) \(ARTCC.locationName)’.", comment: "failure reason")
            case let .invalidFrequency(string):
                return String(localized: "Invalid frequency ‘\(string)’.", comment: "failure reason")
            case let .unknownFSS(ID):
                return String(localized: "Continuation record references unknown FSS ‘\(ID)’.", comment: "failure reason")
            case .notYetLoaded:
                return String(localized: "Attempted to access NASR data before .load() weas called.", comment: "failure reason")
            case let .noSuchFile(path):
                return String(localized: "No such file in distribution: \(path).", comment: "failure reason")
            case let .invalidRunwaySurface(string):
                return String(localized: "Unknown runway surface ‘\(string)’.", comment: "failure reason")
            case let .invalidPavementClassification(string):
                return String(localized: "Unknown pavement classification ‘\(string)’ for PCN.", comment: "failure reason")
            case let .invalidVGSI(string):
                return String(localized: "Unknown VGSI identifier ‘\(string)’.", comment: "failure reason")
            case let .unknownNavaid(string):
                return String(localized: "Unknown navaid ‘\(string)’.", comment: "failure reason")
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
            case .nullDistribution:
                return String(localized: "Do not call .load() on a NullDistribution. Use NullDistribution for distributions that were previously loaded and serialized to disk.", comment: "recovery suggestion")
            case .badResponse, .noData:
                return String(localized: "Verify that the URL to the distribution is correct and accessible.", comment: "recovery suggestion")
            case .unknownARTCC, .unknownARTCCFrequency, .unknownFieldID,
                    .unknownFrequencyFieldID, .invalidFrequency, .unknownFSS,
                    .invalidRunwaySurface, .invalidPavementClassification,
                    .invalidVGSI, .unknownNavaid, .noSuchFilePrefix, .noSuchFile:
                return String(localized: "The NASR FADDS format may have changed, requiring an update to SwiftNASR.", comment: "recovery suggestion")
            case .notYetLoaded:
                return String(localized: "Call .load() before accessing NASR data.", comment: "recovery suggestion")
        }
    }
}
