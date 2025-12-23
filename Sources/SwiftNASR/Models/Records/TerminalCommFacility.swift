import Foundation

/// A Terminal Communications Facility (tower, approach control, etc.) providing ATC services.
///
/// Terminal Communications Facilities include airports with VFR and IFR towers, and airports
/// having terminal communications provided by Air Route Traffic Control Centers and Flight
/// Service Stations.
public struct TerminalCommFacility: ParentRecord {

  // MARK: - Identification

  /// Terminal communications facility identifier (e.g., "LAX", "JFK").
  public let facilityId: String

  /// Landing facility site number (e.g., "01818.*A").
  public let airportSiteNumber: String?

  /// Information effective date.
  public let effectiveDateComponents: DateComponents?

  // MARK: - Location Information

  /// FAA region code (e.g., "AWP" for Western-Pacific).
  public let regionCode: String?

  /// Associated state name (e.g., "CALIFORNIA").
  public let stateName: String?

  /// Associated state postal code.
  public let stateCode: String?

  /// Associated city name (e.g., "LOS ANGELES").
  public let city: String?

  /// Official airport name (e.g., "LOS ANGELES INTL").
  public let airportName: String?

  /// Airport reference point position.
  public let position: Location?

  // MARK: - FSS Information

  /// Tie-in Flight Service Station identifier (e.g., "WJF").
  public let tieInFSSId: String?

  /// Tie-in Flight Service Station name (e.g., "LANCASTER").
  public let tieInFSSName: String?

  // MARK: - Facility Information

  /// Type of terminal communications facility.
  public let facilityType: FacilityType?

  /// Number of hours of daily operation (e.g., "16", "24").
  public let hoursOfOperation: String?

  /// Regularity of operation.
  public let operationRegularity: OperationRegularity?

  /// Master airport identifier if this is a satellite airport.
  public let masterAirportId: String?

  /// Name of master airport furnishing services (if satellite).
  public let masterAirportName: String?

  /// Direction finding equipment type.
  public let directionFindingEquipment: DirectionFindingEquipmentType?

  // MARK: - Off-Airport Facility Data

  /// Name of associated landing facility when not on airport.
  public let offAirportFacilityName: String?

  /// City when facility not on airport.
  public let offAirportCity: String?

  /// State when facility not on airport.
  public let offAirportState: String?

  /// State postal code when facility not on airport.
  public let offAirportStateCode: String?

  /// FAA region when facility not on airport.
  public let offAirportRegionCode: String?

  // MARK: - Radar Position Data

  /// Airport Surveillance Radar position.
  public let ASRPosition: Location?

  /// Direction Finding Antenna position.
  public let DFPosition: Location?

  // MARK: - Operator Information

  /// Name of agency operating the tower.
  public let towerOperator: String?

  /// Name of agency conducting military operations.
  public let militaryOperator: String?

  /// Name of agency operating primary approach control.
  public let primaryApproachOperator: String?

  /// Name of agency operating secondary approach control.
  public let secondaryApproachOperator: String?

  /// Name of agency operating primary departure control.
  public let primaryDepartureOperator: String?

  /// Name of agency operating secondary departure control.
  public let secondaryDepartureOperator: String?

  // MARK: - Radio Call Information

  /// Radio call used to contact tower.
  public let towerRadioCall: String?

  /// Radio call for military operations.
  public let militaryRadioCall: String?

  /// Radio call for primary approach control.
  public let primaryApproachRadioCall: String?

  /// Radio call for secondary approach control.
  public let secondaryApproachRadioCall: String?

  /// Radio call for primary departure control.
  public let primaryDepartureRadioCall: String?

  /// Radio call for secondary departure control.
  public let secondaryDepartureRadioCall: String?

  // MARK: - Operation Hours (from TWR2)

  /// Hours of Pilot-to-Metro Service (PMSV).
  public internal(set) var pmsvHours: String?

  /// Hours of Military Aircraft Command Post (MACP).
  public internal(set) var macpHours: String?

  /// Hours of military operations.
  public internal(set) var militaryOperationsHours: String?

  /// Hours of primary approach control.
  public internal(set) var primaryApproachHours: String?

  /// Hours of secondary approach control.
  public internal(set) var secondaryApproachHours: String?

  /// Hours of primary departure control.
  public internal(set) var primaryDepartureHours: String?

  /// Hours of secondary departure control.
  public internal(set) var secondaryDepartureHours: String?

  /// Hours of tower operation.
  public internal(set) var towerHours: String?

  // MARK: - Frequencies (from TWR3)

  /// Communication frequencies and their uses.
  public internal(set) var frequencies = [Frequency]()

  // MARK: - Services (from TWR4)

  /// Services provided by the master airport.
  public internal(set) var masterAirportServices: String?

  // MARK: - Radar (from TWR5)

  /// Radar information for the facility.
  public internal(set) var radar: Radar?

  // MARK: - Airspace (from TWR8)

  /// Airspace classification information.
  public internal(set) var airspace: Airspace?

  // MARK: - ATIS (from TWR9)

  /// ATIS information for the facility.
  public internal(set) var ATISInfo = [ATIS]()

  // MARK: - Satellite Airports (from TWR7)

  /// Satellite airports serviced by this facility.
  public internal(set) var satelliteAirports = [SatelliteAirport]()

  // MARK: - Remarks (from TWR6)

  /// Remarks about the facility.
  public internal(set) var remarks = [String]()

  weak var data: NASRData?

  public var id: String { facilityId }

  // MARK: - Enums

  /// Types of terminal communications facilities.
  public enum FacilityType: String, RecordEnum {
    /// Air Traffic Control Tower.
    case ATCT = "ATCT"

    /// Non-Air Traffic Control Tower (airport with IFR service).
    case nonATCT = "NON-ATCT"

    /// ATCT plus Approach Control.
    case ATCTApproach = "ATCT-A/C"

    /// ATCT plus Radar Approach Control (Air Force operates ATCT/FAA operates approach).
    case ATCTRAPCON = "ATCT-RAPCON"

    /// ATCT plus Radar Approach Control (Navy operates ATCT/FAA operates approach).
    case ATCTRATCF = "ATCT-RATCF"

    /// ATCT plus Terminal Radar Approach Control.
    case ATCTTRACON = "ATCT-TRACON"

    /// Terminal Radar Approach Control (standalone).
    case TRACON = "TRACON"

    /// ATCT plus Terminal Radar Cab.
    case ATCTTRACAB = "ATCT-TRACAB"

    /// ATCT plus Center Radar Approach Control.
    case ATCTCERAP = "ATCT-CERAP"
  }

  /// Regularity of tower operation.
  public enum OperationRegularity: String, RecordEnum {
    /// All days.
    case all = "ALL"

    /// Weekdays only.
    case weekdaysOnly = "WDO"

    /// Weekends only.
    case weekendsOnly = "WEO"

    /// Subject to seasonal adjustment.
    case seasonal = "SEA"

    /// Weekdays with different hours on weekends.
    case weekdaysWithWeekends = "WDE"

    /// Weekdays subject to seasonal adjustment.
    case weekdaysSeasonal = "WDS"

    /// Weekends subject to seasonal adjustment.
    case weekendsSeasonal = "WES"
  }

  /// Direction finding equipment types.
  public enum DirectionFindingEquipmentType: String, RecordEnum {
    /// VHF direction finding.
    case VHF = "VHF"

    /// UHF direction finding.
    case UHF = "UHF"

    /// VHF and UHF direction finding.
    case VHF_UHF = "VHF/UHF"

    /// Doppler VHF direction finding.
    case dopplerVHF = "DOPPLER VHF"

    /// Doppler VHF and UHF direction finding.
    case dopplerVHF_UHF = "DOPPLER VHF/UHF"
  }

  /// Radar service types.
  public enum RadarType: String, RecordEnum {
    /// Radar approach control.
    case radar = "RADAR"

    /// Non-radar service.
    case nonRadar = "NON-RADAR"

    /// Radar approach control (military).
    case RAPCON = "RAPCON"
  }

  // MARK: - Nested Types

  /// Communication frequency and use.
  public struct Frequency: Record {
    /// The frequency (kHz).
    public let frequencyKHz: UInt

    /// Use or purpose of the frequency (e.g., "LCL/P", "GND/P").
    public let use: String?

    /// Sectorization information.
    public let sectorization: String?

    public enum CodingKeys: String, CodingKey {
      case frequencyKHz, use, sectorization
    }
  }

  /// Radar equipment and status.
  public struct Radar: Record {
    /// Primary approach radar type.
    public let primaryApproachRadar: RadarType?

    /// Secondary approach radar type.
    public let secondaryApproachRadar: RadarType?

    /// Primary departure radar type.
    public let primaryDepartureRadar: RadarType?

    /// Secondary departure radar type.
    public let secondaryDepartureRadar: RadarType?

    /// Radar equipment at the tower.
    public internal(set) var equipment = [RadarEquipment]()

    /// Individual radar equipment.
    public struct RadarEquipment: Record {
      /// Type of radar (e.g., "ASR-8", "PAR").
      public let radarType: String

      /// Hours of operation.
      public let hours: String?

      public enum CodingKeys: String, CodingKey {
        case radarType, hours
      }
    }

    public enum CodingKeys: String, CodingKey {
      case primaryApproachRadar, secondaryApproachRadar
      case primaryDepartureRadar, secondaryDepartureRadar
      case equipment
    }
  }

  /// Airspace classification.
  public struct Airspace: Record {
    /// Class B airspace present.
    public let classB: Bool

    /// Class C airspace present.
    public let classC: Bool

    /// Class D airspace present.
    public let classD: Bool

    /// Class E airspace present.
    public let classE: Bool

    /// Hours the airspace is active.
    public let hours: String?

    public enum CodingKeys: String, CodingKey {
      case classB, classC, classD, classE, hours
    }
  }

  /// ATIS (Automatic Terminal Information Service) data.
  public struct ATIS: Record {
    /// ATIS serial number.
    public let serialNumber: UInt

    /// Hours of operation.
    public let hours: String?

    /// Description of purpose.
    public let description: String?

    /// Phone number.
    public let phoneNumber: String?

    public enum CodingKeys: String, CodingKey {
      case serialNumber, hours, description, phoneNumber
    }
  }

  /// Satellite airport information.
  public struct SatelliteAirport: Record {
    /// Frequency for satellite airport (kHz).
    public let frequencyKHz: UInt?

    /// Frequency use (e.g., "APCH/P DEP/P").
    public let frequencyUse: String?

    /// Satellite airport site number.
    public let airportSiteNumber: String?

    /// Satellite airport identifier.
    public let airportId: String?

    /// FAA region code.
    public let regionCode: String?

    /// State name.
    public let stateName: String?

    /// State postal code.
    public let stateCode: String?

    /// City name.
    public let city: String?

    /// Airport name.
    public let airportName: String?

    /// Airport position.
    public let position: Location?

    /// Flight Service Station identifier.
    public let FSSId: String?

    /// Flight Service Station name.
    public let FSSName: String?

    /// Master airport site number.
    public let masterAirportSiteNumber: String?

    /// Master airport region code.
    public let masterAirportRegionCode: String?

    /// Master airport state name.
    public let masterAirportStateName: String?

    /// Master airport state postal code.
    public let masterAirportStateCode: String?

    /// Master airport city.
    public let masterAirportCity: String?

    /// Master airport name.
    public let masterAirportName: String?

    public enum CodingKeys: String, CodingKey {
      case frequencyKHz, frequencyUse, airportSiteNumber, airportId
      case regionCode, stateName, stateCode, city, airportName
      case position, FSSId, FSSName
      case masterAirportSiteNumber, masterAirportRegionCode
      case masterAirportStateName, masterAirportStateCode
      case masterAirportCity, masterAirportName
    }
  }

  public enum CodingKeys: String, CodingKey {
    case facilityId, airportSiteNumber
    case effectiveDateComponents = "effectiveDate"
    case regionCode, stateName, stateCode, city, airportName
    case position, tieInFSSId, tieInFSSName
    case facilityType, hoursOfOperation, operationRegularity
    case masterAirportId, masterAirportName, directionFindingEquipment
    case offAirportFacilityName, offAirportCity, offAirportState
    case offAirportStateCode, offAirportRegionCode
    case ASRPosition, DFPosition
    case towerOperator, militaryOperator
    case primaryApproachOperator, secondaryApproachOperator
    case primaryDepartureOperator, secondaryDepartureOperator
    case towerRadioCall, militaryRadioCall
    case primaryApproachRadioCall, secondaryApproachRadioCall
    case primaryDepartureRadioCall, secondaryDepartureRadioCall
    case pmsvHours, macpHours, militaryOperationsHours
    case primaryApproachHours, secondaryApproachHours
    case primaryDepartureHours, secondaryDepartureHours, towerHours
    case frequencies, masterAirportServices, radar, airspace
    case ATISInfo, satelliteAirports, remarks
  }
}
