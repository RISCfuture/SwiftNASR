import Foundation

/// A segment of an ARTCC (Air Route Traffic Control Center) boundary.
///
/// ARTCC boundaries are composed of connected boundary points that form closed shapes.
/// Each segment contains a single point and a description of the boundary line
/// connecting to the next point.
///
/// Note: Some ARTCC boundaries are composed of multiple closed shapes. In these cases,
/// the description text will contain "TO POINT OF BEGINNING" to indicate where a shape
/// closes and returns to its starting point.
public struct ARTCCBoundarySegment: Record, Identifiable {

  // MARK: - Identification

  /// The full record identifier (ARTCC ID + altitude code + point designator)
  public let recordIdentifier: String

  /// The ARTCC identifier (e.g., "ZLA", "ZNY")
  public let ARTCCIdentifier: String

  /// The altitude structure (high or low)
  public let altitudeStructure: AltitudeStructure?

  /// The five-character boundary point designator
  public let pointDesignator: String

  /// The center name (e.g., "LOS ANGELES CENTER")
  public let centerName: String

  /// The altitude structure decode name (e.g., "LOW", "HIGH")
  public let altitudeStructureName: String

  // MARK: - Location

  /// The position of the boundary point.
  public let position: Location

  // MARK: - Boundary Description

  /// Description of the boundary line connecting this point to the next point
  public let boundaryDescription: String

  /// Six-digit sequence number for maintaining proper order of boundary segments
  public let sequenceNumber: UInt

  /// Whether this point is used only in the NAS description (not the legal description)
  public let NASDescriptionOnly: Bool?

  /// Reference to parent NASRData for cross-referencing.
  weak var data: NASRData?

  public var id: String { recordIdentifier }

  // MARK: - Types

  /// The altitude structure for the boundary segment
  public enum AltitudeStructure: String, RecordEnum, CaseIterable, Equatable, Hashable, Codable,
    Sendable
  {
    case low = "L"
    case high = "H"

    public var description: String {
      switch self {
        case .low: return "Low"
        case .high: return "High"
      }
    }
  }

  public enum CodingKeys: String, CodingKey {
    case recordIdentifier, ARTCCIdentifier, altitudeStructure, pointDesignator
    case centerName, altitudeStructureName, position
    case boundaryDescription, sequenceNumber, NASDescriptionOnly
  }
}
