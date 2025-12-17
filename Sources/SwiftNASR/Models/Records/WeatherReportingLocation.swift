import Foundation

/// A weather reporting location.
///
/// Weather reporting locations are sites where various weather services
/// are available, including METARs, TAFs, PIREPs, SIGMETs, and other
/// aviation weather products.
public struct WeatherReportingLocation: Record, Identifiable {

  // MARK: - Properties

  /// Weather reporting location identifier (e.g., "AGS", "AK21").
  public let identifier: String

  /// Geographic position of the weather reporting location.
  public let position: Location?

  /// Associated city name.
  public let city: String?

  /// Associated state (US postal code) or country code.
  public let stateCode: String?

  /// Associated country numeric code (non-US only, FIPS code).
  public let countryCode: String?

  /// Accuracy of the elevation value.
  public let elevationAccuracy: ElevationAccuracy?

  /// Weather services available at this location.
  public internal(set) var weatherServices: [WeatherServiceType]

  /// Collective information (weather service type + number).
  public internal(set) var collectives: [Collective]

  /// Affected areas for certain weather services.
  public internal(set) var affectedAreas: [AffectedArea]

  public var id: String {
    identifier
  }

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  // MARK: - Types

  /// Type of weather service available at a location.
  public enum WeatherServiceType: String, RecordEnum {
    /// Severe Weather Outlook Narrative
    case severeWeatherOutlook = "AC"

    /// Severe Weather Forecast Alert
    case severeWeatherAlert = "AWW"

    /// Central Weather Advisory
    case centralWeatherAdvisory = "CWA"

    /// Area Forecast
    case areaForecast = "FA"

    /// Winds & Temperature Aloft Forecast
    case windsAloft = "FD"

    /// Aviation Terminal Forecast (legacy)
    case terminalForecast = "FT"

    /// Miscellaneous Forecasts
    case miscForecasts = "FX"

    /// Aviation Routine Weather Report (ICAO)
    case METAR = "METAR"

    /// Meteorological Impact Summary
    case metImpactSummary = "MIS"

    /// Notice to Airmen
    case NOTAM = "NOTAM"

    /// Surface Observation Report
    case surfaceObservation = "SA"

    /// Radar Weather Report
    case radarWeather = "SD"

    /// Aviation Special Weather Report (ICAO)
    case SPECI = "SPECI"

    /// Transcribed Weather Broadcast Synopses
    case TWBSynopses = "SYNS"

    /// Aviation Terminal Forecast (ICAO)
    case TAF = "TAF"

    /// Transcribed Weather Broadcast
    case TWEB = "TWEB"

    /// Aircraft Report (PIREP)
    case PIREP = "UA"

    /// Weather Advisory
    case weatherAdvisory = "WA"

    /// Abbreviated Hurricane Advisory
    case hurricaneAdvisory = "WH"

    /// Tropical Depressions
    case tropicalDepressions = "WO"

    /// Flight Advisory - SIGMET
    case SIGMET = "WS"

    /// Convective SIGMET
    case convectiveSIGMET = "WST"

    /// Severe Weather Broadcasts or Bulletins
    case severeWeatherBroadcasts = "WW"
  }

  /// Accuracy of the elevation value.
  public enum ElevationAccuracy: String, RecordEnum {
    /// Value was surveyed
    case surveyed = "S"

    /// Value was estimated
    case estimated = "E"
  }

  // MARK: - Nested Types

  /// A collective entry for a weather reporting location.
  public struct Collective: Record {
    /// Weather service type (FT or SD).
    public let serviceType: WeatherServiceType?

    /// Collective number (0-9).
    public let number: UInt

    public enum CodingKeys: String, CodingKey {
      case serviceType, number
    }
  }

  /// An affected area entry for a weather reporting location.
  public struct AffectedArea: Record {
    /// Weather service type.
    public let serviceType: WeatherServiceType?

    /// States/areas affected (list of 2-char codes).
    public let states: [String]

    public enum CodingKeys: String, CodingKey {
      case serviceType, states
    }
  }

  public enum CodingKeys: String, CodingKey {
    case identifier, position, city, stateCode, countryCode
    case elevationAccuracy, weatherServices
    case collectives, affectedAreas
  }
}
