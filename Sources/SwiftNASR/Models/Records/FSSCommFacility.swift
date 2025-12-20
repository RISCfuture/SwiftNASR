import Foundation

/// An FSS (Flight Service Station) communications facility/outlet.
///
/// This represents remote communication outlets (RCOs) and other FSS communication facilities
/// that provide pilot briefings, flight plan filing, and other services.
public struct FSSCommFacility: Record, Identifiable {

  // MARK: - Outlet Identification

  /// The communications outlet identifier
  public let outletIdentifier: String

  /// The type of communications outlet
  public let outletType: OutletType?

  // MARK: - Associated Navaid

  /// The identifier of the associated navaid
  public let navaidIdentifier: String?

  /// The type of the associated navaid
  public let navaidType: Navaid.FacilityType?

  /// The city of the associated navaid
  public let navaidCity: String?

  /// The state of the associated navaid
  public let navaidState: String?

  /// The name of the associated navaid
  public let navaidName: String?

  /// The position of the associated navaid.
  public let navaidPosition: Location?

  // MARK: - Outlet Location

  /// The city where the outlet is located
  public let outletCity: String?

  /// The state where the outlet is located
  public let outletState: String?

  /// The region name
  public let regionName: String?

  /// The region code
  public let regionCode: String?

  /// The position of the outlet.
  public let outletPosition: Location?

  /// The outlet call sign
  public let outletCall: String?

  // MARK: - Frequencies

  /// The communication frequencies (up to 16)
  public let frequencies: [Frequency]

  // MARK: - Associated FSS

  /// The identifier of the parent FSS
  public let FSSIdentifier: String?

  /// The name of the parent FSS
  public let FSSName: String?

  /// The identifier of the alternate FSS
  public let alternateFSSIdentifier: String?

  /// The name of the alternate FSS
  public let alternateFSSName: String?

  // MARK: - Operations

  /// Operational hours
  public let operationalHours: String?

  /// The owner code
  public let ownerCode: String?

  /// The owner name
  public let ownerName: String?

  /// The operator code
  public let operatorCode: String?

  /// The operator name
  public let operatorName: String?

  // MARK: - Charts and Status

  /// Chart codes (up to 4)
  public let charts: [String]

  /// Standard time zone
  public let timeZone: StandardTimeZone?

  /// Facility status
  public let status: FSS.Status?

  /// Status effective date
  public let statusDateComponents: DateComponents?

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  public var id: String { outletIdentifier }

  // MARK: - Types

  /// The type of communications outlet
  public enum OutletType: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable, Sendable {
    /// Remote Communication Outlet
    case rco = "RCO"

    /// Remote Communication Outlet (alternate designation)
    case rco1 = "RCO1"

    /// Remote Communications Air/Ground facility
    case RCAG = "RCAG"

    public var description: String {
      switch self {
        case .rco, .rco1: return "Remote Communication Outlet"
        case .RCAG: return "Remote Communications Air/Ground"
      }
    }
  }

  /// A communication frequency used by the outlet.
  public struct Frequency: Record, Equatable, Hashable, Codable, Sendable {

    /// The radio frequency, in kHz.
    public let frequencyKHz: UInt

    /// How this frequency is used.
    public let use: Use?

    /// Frequency use.
    public enum Use: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable, Sendable {
      /// Receive only on this frequency.
      case receiveOnly = "R"

      public var description: String {
        switch self {
          case .receiveOnly: return "Receive Only"
        }
      }
    }
  }

  public enum CodingKeys: String, CodingKey {
    case outletIdentifier, outletType
    case navaidIdentifier, navaidType, navaidCity, navaidState, navaidName
    case navaidPosition
    case outletCity, outletState, regionName, regionCode
    case outletPosition, outletCall
    case frequencies, FSSIdentifier, FSSName
    case alternateFSSIdentifier, alternateFSSName
    case operationalHours, ownerCode, ownerName, operatorCode, operatorName
    case charts, timeZone, status
    case statusDateComponents = "statusDate"
  }
}
