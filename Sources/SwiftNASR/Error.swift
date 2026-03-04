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

  /**
   Download failed for a specific reason.
  
   - Parameter reason: The reason for the failure.
   */
  case downloadFailed(reason: String)

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
  
   - Parameter fieldId: The unknown identifier.
   - Parameter ARTCC: The ARTCC record.
   */
  case unknownFieldId(_ fieldId: String, ARTCC: ARTCC)

  /**
   Parsed an unknown ARTCC frequency data field identifier.
  
   - Parameter fieldId: The unknown identifier.
   - Parameter frequency: The associated frequency.
   - Parameter ARTCC: The ARTCC record.
   */
  case unknownFrequencyFieldId(_ fieldId: String, frequency: ARTCC.CommFrequency, ARTCC: ARTCC)

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

  /**
   Attempted to parse an invalid altitude format.
  
   - Parameter string: The invalid altitude string.
   */
  case invalidAltitudeFormat(_ string: String)
}

extension Error: LocalizedError {
  public var errorDescription: String? {
    switch self {
      case .nullDistribution, .noSuchFilePrefix, .noSuchFile:
        #if canImport(Darwin)
        return String(localized: "Couldn’t load distribution.", comment: "error description")
        #else
        return "Couldn’t load distribution."
        #endif
      case .badResponse, .noData, .downloadFailed:
        #if canImport(Darwin)
        return String(localized: "Couldn’t download distribution.", comment: "error description")
        #else
        return "Couldn’t download distribution."
        #endif
      case .unknownARTCC, .unknownARTCCFrequency, .unknownFieldId,
        .unknownFrequencyFieldId, .invalidFrequency, .unknownFSS,
        .invalidRunwaySurface, .invalidPavementClassification,
        .invalidVGSI, .unknownNavaid, .invalidAltitudeFormat:
        #if canImport(Darwin)
        return String(localized: "Couldn’t parse distribution data.", comment: "error description")
        #else
        return "Couldn’t parse distribution data."
        #endif
      case .notYetLoaded:
        #if canImport(Darwin)
        return String(localized: "This NASR has not been loaded yet.", comment: "error description")
        #else
        return "This NASR has not been loaded yet."
        #endif
    }
  }

  public var failureReason: String? {
    switch self {
      case .nullDistribution:
        #if canImport(Darwin)
        return String(
          localized: "Called .load() on a null distribution.",
          comment: "failure reason"
        )
        #else
        return "Called .load() on a null distribution."
        #endif
      case .badResponse(let response):
        #if canImport(Darwin)
        return String(
          localized: "Bad response: \(response.description).",
          comment: "failure reason"
        )
        #else
        return "Bad response: \(response.description)."
        #endif
      case .downloadFailed(let reason):
        #if canImport(Darwin)
        return String(localized: "Download failed: \(reason)", comment: "failure reason")
        #else
        return "Download failed: \(reason)"
        #endif
      case .noSuchFilePrefix(let prefix):
        #if canImport(Darwin)
        return String(
          localized: "Couldn’t find file in archive with prefix ‘\(prefix).’",
          comment: "failure reason"
        )
        #else
        return "Couldn’t find file in archive with prefix ‘\(prefix).’"
        #endif
      case .noData:
        #if canImport(Darwin)
        return String(localized: "No data was downloaded.", comment: "failure reason")
        #else
        return "No data was downloaded."
        #endif
      case .unknownARTCC(let ID):
        #if canImport(Darwin)
        return String(
          localized: "Referenced undefined ARTCC record with ID ‘\(ID)’.",
          comment: "failure reason"
        )
        #else
        return "Referenced undefined ARTCC record with ID ‘\(ID)’."
        #endif
      case let .unknownARTCCFrequency(frequency, ARTCC):
        #if canImport(Darwin)
        return String(
          localized: "Referenced undefined frequency ‘\(frequency)’ for ARTCC \(ARTCC.code).",
          comment: "failure reason"
        )
        #else
        return "Referenced undefined frequency ‘\(frequency)’ for ARTCC \(ARTCC.code)."
        #endif
      case let .unknownFieldId(fieldId, ARTCC):
        #if canImport(Darwin)
        return String(
          localized: "Unknown field ID ‘\(fieldId)’ at ‘\(ARTCC.code) \(ARTCC.locationName)’.",
          comment: "failure reason"
        )
        #else
        return "Unknown field ID ‘\(fieldId)’ at ‘\(ARTCC.code) \(ARTCC.locationName)’."
        #endif
      case let .unknownFrequencyFieldId(fieldId, frequency, ARTCC):
        #if canImport(Darwin)
        return String(
          localized:
            "Unknown field ID '\(fieldId)' for \(frequency.frequencyKHz) kHz at '\(ARTCC.code) \(ARTCC.locationName)'.",
          comment: "failure reason"
        )
        #else
        return "Unknown field ID '\(fieldId)' for \(frequency.frequencyKHz) kHz at '\(ARTCC.code) \(ARTCC.locationName)'."
        #endif
      case .invalidFrequency(let string):
        #if canImport(Darwin)
        return String(localized: "Invalid frequency ‘\(string)’.", comment: "failure reason")
        #else
        return "Invalid frequency ‘\(string)’."
        #endif
      case .unknownFSS(let ID):
        #if canImport(Darwin)
        return String(
          localized: "Continuation record references unknown FSS ‘\(ID)’.",
          comment: "failure reason"
        )
        #else
        return "Continuation record references unknown FSS ‘\(ID)’."
        #endif
      case .notYetLoaded:
        #if canImport(Darwin)
        return String(
          localized: "Attempted to access NASR data before .load() was called.",
          comment: "failure reason"
        )
        #else
        return "Attempted to access NASR data before .load() was called."
        #endif
      case .noSuchFile(let path):
        #if canImport(Darwin)
        return String(
          localized: "No such file in distribution: \(path).",
          comment: "failure reason"
        )
        #else
        return "No such file in distribution: \(path)."
        #endif
      case .invalidRunwaySurface(let string):
        #if canImport(Darwin)
        return String(localized: "Unknown runway surface ‘\(string)’.", comment: "failure reason")
        #else
        return "Unknown runway surface ‘\(string)’."
        #endif
      case .invalidPavementClassification(let string):
        #if canImport(Darwin)
        return String(
          localized: "Unknown pavement classification ‘\(string)’ for PCN.",
          comment: "failure reason"
        )
        #else
        return "Unknown pavement classification ‘\(string)’ for PCN."
        #endif
      case .invalidVGSI(let string):
        #if canImport(Darwin)
        return String(localized: "Unknown VGSI identifier ‘\(string)’.", comment: "failure reason")
        #else
        return "Unknown VGSI identifier ‘\(string)’."
        #endif
      case .unknownNavaid(let string):
        #if canImport(Darwin)
        return String(localized: "Unknown navaid ‘\(string)’.", comment: "failure reason")
        #else
        return "Unknown navaid ‘\(string)’."
        #endif
      case .invalidAltitudeFormat(let string):
        #if canImport(Darwin)
        return String(localized: "Invalid altitude format ‘\(string)’.", comment: "failure reason")
        #else
        return "Invalid altitude format ‘\(string)’."
        #endif
    }
  }

  public var recoverySuggestion: String? {
    switch self {
      case .nullDistribution:
        #if canImport(Darwin)
        return String(
          localized:
            "Do not call .load() on a NullDistribution. Use NullDistribution for distributions that were previously loaded and serialized to disk.",
          comment: "recovery suggestion"
        )
        #else
        return "Do not call .load() on a NullDistribution. Use NullDistribution for distributions that were previously loaded and serialized to disk."
        #endif
      case .badResponse, .noData, .downloadFailed:
        #if canImport(Darwin)
        return String(
          localized: "Verify that the URL to the distribution is correct and accessible.",
          comment: "recovery suggestion"
        )
        #else
        return "Verify that the URL to the distribution is correct and accessible."
        #endif
      case .unknownARTCC, .unknownARTCCFrequency, .unknownFieldId,
        .unknownFrequencyFieldId, .invalidFrequency, .unknownFSS,
        .invalidRunwaySurface, .invalidPavementClassification,
        .invalidVGSI, .unknownNavaid, .noSuchFilePrefix, .noSuchFile,
        .invalidAltitudeFormat:
        #if canImport(Darwin)
        return String(
          localized: "The NASR FADDS format may have changed, requiring an update to SwiftNASR.",
          comment: "recovery suggestion"
        )
        #else
        return "The NASR FADDS format may have changed, requiring an update to SwiftNASR."
        #endif
      case .notYetLoaded:
        #if canImport(Darwin)
        return String(
          localized: "Call .load() before accessing NASR data.",
          comment: "recovery suggestion"
        )
        #else
        return "Call .load() before accessing NASR data."
        #endif
    }
  }
}
