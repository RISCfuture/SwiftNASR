import Foundation

/// Errors that can occur in SwiftNASR methods.
public enum Error: Swift.Error {
    /// Tried to call ``NASR/load(withProgress:callback:)`` on a ``NASR``
    /// instance with a null distribution.
    case nullDistribution
    
    /**
     Received a bad HTTP response.
     
     - Parameter response: The HTTP response.
     */
    case badResponse(_ response: URLResponse)
    
    /// Downloaded tempfile unexpectedly missing.
    case noFile
    
    /// No file in distribution archive.
    case noSuchFile(path: String)
    
    /// No such file by prefix in distribution archive.
    case noSuchFilePrefix(_ prefix: String)
    
    /// Response did not contain any body.
    case noData
    
    /// ``NASR/parse(_:withProgress:errorHandler:completionHandler:)`` was
    /// called before ``NASR/load(withProgress:callback:)``.
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
            case .nullDistribution, .noFile, .noSuchFilePrefix, .noSuchFile:
                return t("Couldn’t load distribution.", comment: "error description")
            case .badResponse, .noData:
                return t("Couldn’t download distribution.", comment: "error description")
            case .unknownARTCC, .unknownARTCCFrequency, .unknownFieldID,
                    .unknownFrequencyFieldID, .invalidFrequency, .unknownFSS,
                    .invalidRunwaySurface, .invalidPavementClassification,
                    .invalidVGSI, .unknownNavaid:
                return t("Couldn’t parse distribution data.", comment: "error description")
            case .notYetLoaded:
                return t("This NASR has not been loaded yet.", comment: "error description")
        }
    }
    
    public var failureReason: String? {
        switch self {
            case .nullDistribution:
                return t("Called .load() on a null distribution.", comment: "failure reason")
            case let .badResponse(response):
                return t("Bad response: %@.", comment: "failure reason",
                         response.description)
            case .noFile:
                return t("Couldn’t find file to load.", comment: "failure reason")
            case let .noSuchFilePrefix(prefix):
                return t("Couldn’t find file in archive with prefix “%@.”", comment: "failure reason",
                         prefix)
            case .noData:
                return t("No data was downloaded.", comment: "failure reason")
            case let .unknownARTCC(ID):
                return t("Referenced undefined ARTCC record with ID ‘%@’.", comment: "failure reason",
                         ID)
            case let .unknownARTCCFrequency(frequency, ARTCC):
                return t("Referenced undefined frequency ‘%@’ for ARTCC %@.", comment: "failure reason",
                         frequency, ARTCC.ID)
            case let .unknownFieldID(fieldID, ARTCC):
                return t("Unknown field ID ‘%@’ at ‘%@ %@’.", comment: "failure reason",
                         fieldID, ARTCC.ID, ARTCC.locationName)
            case let .unknownFrequencyFieldID(fieldID, frequency, ARTCC):
                return t("Unknown field ID ‘%@’ for %@ kHz at ‘%@ %@’.", comment: "failure reason",
                         fieldID, frequency.frequency, ARTCC.ID, ARTCC.locationName)
            case let .invalidFrequency(string):
                return t("Invalid frequency ‘%@’.", comment: "failure reason",
                         string)
            case let .unknownFSS(ID):
                return t("Continuation record references unknown FSS ‘%@’.", comment: "failure reason",
                         ID)
            case .notYetLoaded:
                return t("Attempted to access NASR data before .load() weas called.", comment: "failure reason")
            case let .noSuchFile(path):
                return t("No such file in distribution: %@.", comment: "failure reason",
                         path)
            case let .invalidRunwaySurface(string):
                return t("Unknown runway surface ‘%@’.", comment: "failure reason",
                         string)
            case let .invalidPavementClassification(string):
                return t("Unknown pavement classification ‘%@’ for PCN.", comment: "failure reason",
                         string)
            case let .invalidVGSI(string):
                return t("Unknown VGSI identifier ‘%@’.", comment: "failure reason",
                         string)
            case let .unknownNavaid(string):
                return t("Unknown navaid ‘%@’.", comment: "failure reason",
                         string)
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
            case .nullDistribution:
                return t("Do not call .load() on a NullDistribution. Use NullDistribution for distributions that were previously loaded and serialized to disk.", comment: "recovery suggestion")
            case .noFile:
                return t("Verify that the path to the distribution is correct.", comment: "recovery suggestion")
            case .badResponse, .noData:
                return t("Verify that the URL to the distribution is correct and accessible.", comment: "recovery suggestion")
            case .unknownARTCC, .unknownARTCCFrequency, .unknownFieldID,
                    .unknownFrequencyFieldID, .invalidFrequency, .unknownFSS,
                    .invalidRunwaySurface, .invalidPavementClassification,
                    .invalidVGSI, .unknownNavaid, .noSuchFilePrefix, .noSuchFile:
                return t("The NASR FADDS format may have changed, requiring an update to SwiftNASR.", comment: "recovery suggestion")
            case .notYetLoaded:
                return t("Call .load() before accessing NASR data.", comment: "recovery suggestion")
        }
    }
}

fileprivate func t(_ key: String, comment: String, _ arguments: CVarArg...) -> String {
    let format = NSLocalizedString(key, bundle: Bundle.module, comment: comment)
    if arguments.isEmpty {
        return format
    } else {
        return String(format: format, arguments: arguments)
    }
}
