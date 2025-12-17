import Foundation

/// A Coded Departure Route (CDR).
///
/// CDRs are pre-planned, pre-coordinated routes used to help air traffic control
/// manage traffic flow during periods of congestion or when severe weather
/// affects the national airspace system.
public struct CodedDepartureRoute: Record, Identifiable {

  // MARK: - Properties

  /// Unique route code (e.g., "ORDLAX01").
  public let routeCode: String

  /// Origin airport ICAO identifier (e.g., "KORD").
  public let origin: String

  /// Destination airport ICAO identifier (e.g., "KLAX").
  public let destination: String

  /// Departure fix identifier (e.g., "MZV").
  public let departureFix: String

  /// Full route string (e.g., "KORD MZV LMN J64 CIVET CIVET4 LAX").
  public let routeString: String

  /// ARTCC identifier (e.g., "KZAU").
  public let ARTCCIdentifier: String

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  public var id: String {
    routeCode
  }

  /// The individual components of the route (airports, fixes, airways, procedures).
  ///
  /// Parses the `routeString` by splitting on whitespace. Each component may be
  /// an airport identifier, navaid, fix, airway, SID, or STAR.
  public var routeComponents: [String] {
    routeString.split(separator: " ").map(String.init)
  }

  public enum CodingKeys: String, CodingKey {
    case routeCode, origin, destination, departureFix, routeString, ARTCCIdentifier
  }
}
