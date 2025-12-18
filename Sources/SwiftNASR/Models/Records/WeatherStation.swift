import Foundation

/// An Automated Weather Observing System (AWOS) or Automated Surface Observing System (ASOS) station.
///
/// Weather stations provide real-time weather information to pilots via radio frequencies
/// or telephone. They automatically measure and broadcast weather conditions including
/// visibility, temperature, wind speed and direction, and other meteorological data.
public struct WeatherStation: ParentRecord {

  /// The station identifier (e.g., "SFO", "00U").
  public let stationId: String

  /// The type of weather station.
  public let type: StationType

  /// The state where the station is located.
  public let stateCode: String?

  /// The city where the station is located.
  public let city: String?

  /// The country code (typically "US").
  public let country: String?

  /// Whether the station is commissioned (operational).
  public let isCommissioned: Bool

  /// The date the station was commissioned or decommissioned.
  public let commissionDateComponents: DateComponents?

  /// Whether the station is associated with a navaid.
  public let isNavaidAssociated: Bool?

  /// The geographic position of the station.
  public let position: Location?

  /// How the station location was surveyed.
  public let surveyMethod: SurveyMethod?

  /// The primary frequency for receiving weather broadcasts (kHz).
  public let frequencyKHz: UInt?

  /// The secondary frequency for receiving weather broadcasts (kHz).
  public let secondaryFrequencyKHz: UInt?

  /// The primary phone number for the station.
  public let phoneNumber: String?

  /// The secondary phone number for the station.
  public let secondaryPhoneNumber: String?

  /// The landing facility site number if located at an airport.
  public let airportSiteNumber: String?

  /// Remarks about the station.
  public internal(set) var remarks = [String]()

  weak var data: NASRData?

  public var id: String { stationId }

  /// Types of weather observation stations.
  public enum StationType: String, RecordEnum {
    /// Automated Surface Observing System (full capability).
    case ASOS

    /// AWOS Level 1 - Reports altimeter setting, wind, temperature, dewpoint.
    case AWOS1 = "AWOS-1"

    /// AWOS Level 2 - AWOS-1 plus visibility.
    case AWOS2 = "AWOS-2"

    /// AWOS Level 3 - AWOS-2 plus cloud/ceiling data.
    case AWOS3 = "AWOS-3"

    /// AWOS Level 4 - AWOS-3 plus precipitation identification.
    case AWOS4 = "AWOS-4"

    /// AWOS Aviation - Airport-specific AWOS.
    case AWOSA = "AWOS-A"

    /// ASOS Type A.
    case ASOSA = "ASOS-A"

    /// ASOS Type B.
    case ASOSB = "ASOS-B"

    /// ASOS Type C.
    case ASOSC = "ASOS-C"

    /// ASOS Type D.
    case ASOSD = "ASOS-D"

    /// Automated Weather Sensor System.
    case AWSS

    /// AWOS-3 with thunderstorm detection.
    case AWOS3T = "AWOS-3T"

    /// AWOS-3 with precipitation identification.
    case AWOS3P = "AWOS-3P"

    /// AWOS-3 with thunderstorm and precipitation detection.
    case AWOS3PT = "AWOS-3PT"

    /// AWOS Aviation (variant).
    case AWOSAV = "AWOS-AV"

    /// Weather Equipment Facility.
    case WEF

    /// Stand-Alone Weather System.
    case SAWS
  }

  public enum CodingKeys: String, CodingKey {
    case stationId, type, stateCode, city, country
    case isCommissioned, isNavaidAssociated
    case position, surveyMethod
    case frequencyKHz, secondaryFrequencyKHz, phoneNumber, secondaryPhoneNumber
    case airportSiteNumber, remarks

    case commissionDateComponents = "commissionDate"
  }
}
