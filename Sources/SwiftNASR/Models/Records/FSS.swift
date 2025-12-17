import Foundation

/**
 Flight service stations are FAA facilities that provide in-flight information
 to pilots but do not provide separation services (except in limited local cases
 when the FSS is associated with an uncontrolled airport).

 Fields in this model that reference other record types (e.g.,
 ``airport``, which references ``Airport``) will be `nil` unless the
 associated type has been parsed with ``NASR/parse(_:withProgress:errorHandler:)``.
 */

public struct FSS: ParentRecord {

  // MARK: - Properties

  // MARK: Identifiers

  /// The unique identifying code for the FSS.
  public let id: String

  /// The FSS name.
  public let name: String

  /// The FSS's radio callsign.
  public let radioIdentifier: String?

  // MARK: Basic Info

  /// The type of FSS facility.
  public let type: FSSType

  /// The hours during which the FSS is operational.
  public let hoursOfOperation: String

  /// The status of the FSS.
  public let status: Status?

  /// The chart number for the low-altitude enroute chart that the FSS appears
  /// under.
  public let lowAltEnrouteChartNumber: String?

  /// The phone number that the FSS can be reached from on the ground (e.g.,
  /// for closing VFR flight plans).
  public let phoneNumber: String?

  // MARK: Communications

  /// The frequencies that the FSS monitors.
  public let frequencies: [Frequency]

  /// The frequencies that the FSS communicates with aircraft on.
  public internal(set) var commFacilities: [CommFacility]

  /// The remote communications outlets that the FSS uses to communicate with
  /// aircraft.
  public internal(set) var outlets: [Outlet]

  /// The navigational aids that the FSS monitors.
  public internal(set) var navaids: [Navaid]

  /// The airport advisory frequencies that the FSS monitors.
  public let airportAdvisoryFrequencies: [Frequency]

  /// The VOLMET frequencies that the FSS monitors.
  public let VOLMETs: [VOLMET]

  // MARK: Operator

  /// The type of organization that owns the FSS.
  public let owner: Operator?

  /// The name of the organization that owns the FSS.
  public let ownerName: String?

  /// The type of organization that operates the FSS.
  public let `operator`: Operator

  /// The name of the organization that operates the FSS.
  public let operatorName: String?

  // MARK: Capabilities

  /// `true` if this FSS has weather radar capability.
  public let hasWeatherRadar: Bool?

  /// `true` if this FSS is an enroute flight advisory service.
  public let hasEFAS: Bool?

  /// `true` if this FSS monitors Flight Watch frequencies (decomissioned).
  public let flightWatchAvailability: String?

  /// `true` if this FSS has direction-finding equipment to assist with
  /// locating aircraft.
  public let DFEquipment: DirectionFindingEquipment?

  /// The ID of the nearest FSS with teletype capability.
  public let nearestFSSIdWithTeletype: String?

  // MARK: Location

  /// The FAA location identifier (not site number) of the airport this FSS
  /// is associated with, if any.
  public let airportId: String?

  /// The city associated with the FSS, when the FSS is not located on an
  /// airport.
  public let city: String?

  /// The name of the state associated with the FSS, when the FSS is not
  /// located on an airport.
  public let stateName: String?

  /// The region associated with the FSS, when the FSS is not located on an
  /// airport.
  public let region: String?

  /// The location of the FSS facility, when the FSS is not located on an
  /// airport.
  public let location: Location?

  // MARK: Remarks

  /// Remarks for the flight service station.
  public internal(set) var remarks: [String]

  /// Communications remarks for the FSS.
  public internal(set) var commRemarks: [String]

  weak var data: NASRData?

  // MARK: - Methods

  init(
    id: String,
    airportId: String?,
    name: String,
    radioIdentifier: String?,
    type: FSSType,
    hoursOfOperation: String,
    status: Status?,
    lowAltEnrouteChartNumber: String?,
    frequencies: [Frequency],
    commFacilities: [CommFacility],
    outlets: [Outlet],
    navaids: [Navaid],
    airportAdvisoryFrequencies: [Frequency],
    VOLMETs: [VOLMET],
    owner: Operator?,
    ownerName: String?,
    operator: Operator,
    operatorName: String?,
    hasWeatherRadar: Bool?,
    hasEFAS: Bool?,
    flightWatchAvailability: String?,
    nearestFSSIdWithTeletype: String?,
    city: String?,
    stateName: String?,
    region: String?,
    location: Location?,
    DFEquipment: DirectionFindingEquipment?,
    phoneNumber: String?,
    remarks: [String],
    commRemarks: [String]
  ) {
    self.id = id
    self.airportId = airportId
    self.name = name
    self.radioIdentifier = radioIdentifier
    self.type = type
    self.hoursOfOperation = hoursOfOperation
    self.status = status
    self.lowAltEnrouteChartNumber = lowAltEnrouteChartNumber
    self.frequencies = frequencies
    self.commFacilities = commFacilities
    self.outlets = outlets
    self.navaids = navaids
    self.airportAdvisoryFrequencies = airportAdvisoryFrequencies
    self.VOLMETs = VOLMETs
    self.owner = owner
    self.ownerName = ownerName
    self.operator = `operator`
    self.operatorName = operatorName
    self.hasWeatherRadar = hasWeatherRadar
    self.hasEFAS = hasEFAS
    self.flightWatchAvailability = flightWatchAvailability
    self.nearestFSSIdWithTeletype = nearestFSSIdWithTeletype
    self.city = city
    self.stateName = stateName
    self.region = region
    self.location = location
    self.DFEquipment = DFEquipment
    self.phoneNumber = phoneNumber
    self.remarks = remarks
    self.commRemarks = commRemarks
  }

  private enum CodingKeys: String, CodingKey {
    case id, name, radioIdentifier, type, hoursOfOperation, status, lowAltEnrouteChartNumber,
      phoneNumber, frequencies, commFacilities, outlets, navaids, airportAdvisoryFrequencies,
      VOLMETs, owner, ownerName, `operator`, operatorName, hasWeatherRadar, hasEFAS,
      flightWatchAvailability, DFEquipment, nearestFSSIdWithTeletype, airportId, city, region,
      location, remarks, commRemarks, stateName
  }

  // MARK: - Enums

  /// FSS facility types.
  public enum FSSType: String, RecordEnum {

    /// Flight service station
    case FSS = "FSS"

    /// Flight service station outside the USA
    case internationalFSS = "IFSS"

    /// Air-to-ground facility
    case airGroundFacility = "A/G"

    /// Military BASEOPS facility
    case baseOps = "BASEOPS"

    /// Lockheed-Martin Flight Services for the 21st Century (FS21)
    /// automated FSS hub
    case FS21HubStation = "HUB"

    /// Lockheed-Martin FS21 service area
    case FS21RadioServiceArea = "RADIO"

    /// Combined FSS and air traffic control tower
    case combinedStationTower = "CS/T"
  }

  // MARK: - Structs

  /// A communications frequency used by an FSS to communicate with aircraft.
  public struct Frequency: Record {

    /// The radio frequency, in kHz.
    let frequency: UInt

    /// The FSS callsign used on this frequency.
    let name: String?

    /// `true` if this frequency uses a single sideband only (typically the
    /// upper sideband).
    let singleSideband: Bool

    /// How this frequency is used by the FSS.
    let use: Use?

    /// Frequency use by the FSS.
    public enum Use: String, Record {

      /// The FSS transmits only on this frequency.
      case transmitOnly = "T"

      /// The FSS receives only on this frequency.
      case receiveOnly = "R"

      /// The FSS transmits and receives on this frequency.
      case transmitReceive = "X"
    }
  }

  /// A remote communications outlet (transmit/receive facility) used by an
  /// FSS.
  public struct Outlet: Record {

    /// The outlet ID.
    public let identification: String

    /// The outlet type.
    public let type: OutletType

    /// Type of remote communications outlets.
    public enum OutletType: String, RecordEnum {
      case RCO
      case RCO1
    }
  }

  /// A navigational facility monitored by an FSS.
  public struct Navaid: Record {

    /// The navaid identifier.
    public let identification: String

    /// The navaid type.
    public let type: SwiftNASR.Navaid.FacilityType
  }

  /// A frequency that automatically transmits meteorological information to
  /// pilots.
  public struct VOLMET: Record {

    /// The frequency the meteorological information is transmitted on.
    public let frequency: Frequency

    /// The schedule during which the information is transmitted.
    public let schedule: String
  }

  /// A communications facility used by an FSS.
  public struct CommFacility: Record {

    /// The frequency that the FSS uses to communicate with aircraft.
    public let frequency: Frequency

    /// The hours that the facility is operational.
    public let operationalHours: String?

    /// The city associated with the comm facility.
    public let city: String?

    /// The name of the state associated with the comm facility.
    public let stateName: String?

    /// The geographic location of the comm facility.
    public let location: Location?

    /// The low-altitude enroute chart that the comm facility appears on.
    public let lowAltEnrouteChart: String?

    /// The timezone containing the comm facility.
    public let timezone: StandardTimeZone?

    /// The type of owner of this facility.
    public let owner: Operator?

    /// The name of the owner of this facility.
    public let ownerName: String?

    /// The type of operator of this facility.
    public let `operator`: Operator?

    /// The name of the operator of this facility.
    public let operatorName: String?

    /// The comm facility status.
    public let status: Status?

    /// The date that the current status was last updated.
    public let statusDate: DateComponents?

    /// The navaid ID associated with this comm facility.
    public let navaid: String?

    /// The navaid type associated with this comm facility.
    public let navaidType: SwiftNASR.Navaid.FacilityType?

    // for loading states from the parent FSS object
    var findStateByName: (@Sendable (_ name: String) async -> State?)!

    enum CodingKeys: String, CodingKey {
      case frequency, operationalHours, city, stateName, location, lowAltEnrouteChart, timezone,
        owner, ownerName, `operator`, operatorName, status, statusDate, navaid, navaidType
    }
  }

  /// Direction-finding equipment that an FSS can use to locate aircraft.
  public struct DirectionFindingEquipment: Record {

    /// The direction-finding equipment type.
    public let type: String  // TODO enum?

    /// The location of the DF receiver.
    public let location: Location
  }

  // MARK: - Enums

  /// Owner or operator of an FSS.
  public enum Operator: String, RecordEnum {

    /// United States Air Force
    case USAF = "A"

    /// United States Coast Guard
    case USCG = "C"

    /// Transport Canada
    case TC = "D"

    /// Federal Aviation Administration
    case FAA = "F"

    /// Owned/operated by a foreign federal government
    case foreignFederalGovernment = "G"

    /// United States Navy
    case USN = "N"

    /// Other owner or operator not on this list
    case other = "O"

    /// Private owner or operator
    case `private` = "P"

    /// United States Army
    case USArmy = "R"

    /// Royal Canadian Air Force
    case RCAF = "X"

    /// Ownership or operator is unknown
    case unknown = "Z"
  }

  /// FSS statuses.
  public enum Status: String, RecordEnum {

    /// Operational and providing IFR services
    case operationalIFR = "OPERATIONAL-IFR"

    /// Operational part-time
    case operationalPartTime = "OPNL-PART-TIME"

    /// Decomissioning has been delayed
    case decomissioningDelayed = "DCMSNG DELAYED"
  }
}
