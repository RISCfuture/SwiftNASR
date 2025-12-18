import Foundation

/// A radio navigational aid such as a VOR or an NDB.
///
/// Navaids are uniquely identified by their name and facility type; for example,
/// the Astoria VOR/DME is distinct from the Astoria fan marker though they both
/// have the identifier "AST".
///
/// Fields in this model that reference other record types (e.g.,
/// ``lowAltitudeARTCC``, which references ``ARTCC``) will be `nil` unless the
/// associated type has been parsed with ``NASR/parse(_:withProgress:errorHandler:)`.
public struct Navaid: ParentRecord {

  /// The FAA identifier for this navaid (e.g., "OAK").
  public let id: String

  /// The navaid facility name (e.g., "OAKLAND VORTAC").
  public let name: String

  /// The facility type, such as VOR or NDB.
  public let type: FacilityType

  /// The city that the navaid is associated with.
  public let city: String

  /// The name of the state containing ``city``.
  public let stateName: String?

  /// The FAA administrative region responsible for this navaid.
  public let FAARegion: String

  /// The country containing this navaid (`nil` if it is a US navaid).
  public let country: String?

  /// The name of the organization that owns this navaid.
  public let ownerName: String?

  /// The name of the organization that operates this navaid.
  public let operatorName: String?

  public let commonSystemUsage: Bool

  /// True if this navaid is available for public use.
  public let publicUse: Bool

  /// The altitude and class codes for the navaid.
  public let navaidClass: NavaidClass?

  /// The hours the navaid is operational, as a human-readable string.
  public let hoursOfOperation: String?

  let highAltitudeARTCCCode: String?

  let lowAltitudeARTCCCode: String?

  /// The location and elevation of the navaid.
  public let position: Location

  /// The location and elevation of the TACAN transmitter (for a VORTAC, and
  /// if the TACAN is more than 260 feet away from the VOR).
  public let TACANPosition: Location?

  /// The accuracy of the surveyed location.
  public let surveyAccuracy: SurveyAccuracy?

  /// The magnetic variation at the location of the navaid, in degrees (east
  /// is positive).
  public let magneticVariationDeg: Int?

  /// The epoch date of the magnetic variation data.
  public let magneticVariationEpochComponents: DateComponents?

  /// True if this navaid supports simultaneous voice transmission.
  public let simultaneousVoice: Bool?

  /// The power output of the navaid transmitter (watts).
  public let powerOutputW: UInt?

  /// True if this navaid supports automatic voice identification.
  public let automaticVoiceId: Bool?

  /// The type and status of navaid monitoring.
  public let monitoringCategory: MonitoringCategory?

  /// The radio voice callsign for the navaid.
  public let radioVoiceCall: String?

  /// The channel and band for the TACAN transmitter, if applicable.
  public let tacanChannel: TACANChannel?

  /// The frequency that this navaid transmits on, if applicable (kHz).
  public let frequencyKHz: UInt?

  /// The beacon identifier for a fan marker or marine radio beacon, described
  /// in human-readable Morse code (e.g., "DOT DASH DOT").
  public let beaconIdentifier: String?

  /// The fan marker type, if applicable.
  public let fanMarkerType: FanMarkerType?

  /// The major bearing of the fan marker, if applicable. The fan marker
  /// reception cone is longest along this bearing.
  public let fanMarkerMajorBearing: Bearing<UInt>?

  /// The service volume of a VOR.
  public let VORServiceVolume: ServiceVolume?

  /// The service volume of a DME, or the DME part of a VOR/DME.
  public let DMEServiceVolume: ServiceVolume?

  /// True if this is a low-altitude navaid used as part of the high-altitude
  /// enroute structure.
  public let lowAltitudeInHighStructure: Bool?

  /// True if this is an airway marker with a paired "Z" marker. A "Z" marker
  /// is a low-power marker beacon used to accurately indicate station
  /// passage on the now-obsolete red airways. The airway marker was greater
  /// power with a larger reception cone.
  public let ZMarkerAvailable: Bool?

  /// The hours of operation for the transcribed weather broadcast, if
  /// applicable.
  public let TWEBHours: String?
  /// The phone number for the transcribed weather broadcast, if applicable.
  public let TWEBPhone: String?

  let controllingFSSCode: String?

  public let NOTAMAccountabilityCode: String?

  /// Quadrant identifications and range leg bearings for low frequency
  /// ranges.
  public let LFRLegs: [LFRLeg]?

  /// The operational status of the navaid.
  public let status: OperationalStatus

  /// True if this navaid is used as a pitch point for the High Altitude
  /// Redesign.
  public let isPitchPoint: Bool?

  /// True if this navaid is used as a catch point for the High Altitude
  /// Redesign.
  public let isCatchPoint: Bool?

  /// True if this navaid is associated with special-use airspace (SUA) or
  /// air traffic control-assigned airspace (ATCAA).
  public let isAssociatedWithSUA: Bool?

  /// True if this navaid has restrictions on its use.
  public let hasRestriction: Bool?

  /// True if this navaid broadcasts hazardous in-flight weather advisories.
  public let broadcastsHIWAS: Bool?

  /// True if the transcribed weather broadcast has restrictions.
  public let hasTWEBRestriction: Bool?

  /// The freeform remarks associated with this navaid.
  public internal(set) var remarks = [String]()

  /// Fixes defined by this navaid.
  public internal(set) var associatedFixNames = Set<String>()

  /// Holding patterns defined by this navaid.
  public internal(set) var associatedHoldingPatterns = Set<HoldingPatternId>()

  /// Fan markers associated with this naviad.
  public internal(set) var fanMarkers = Set<String>()

  /// VOR test checkpoints (airborne or ground) defined by this navaid.
  public internal(set) var checkpoints = [VORCheckpoint]()

  weak var data: NASRData?

  /// True if this navaid is available for use (IFR or VFR).
  public var isOperational: Bool {
    status == .operationalIFR || status == .operationalVFROnly || status == .operationalRestricted
  }

  /// True if this navaid is a VOR, VOR/DME, or VORTAC.
  public var isVOR: Bool {
    type == .VOR || type == .VORDME || type == .VORTAC
  }

  /**
   True if this navaid is an NDB or NDB/DME.
  
   Returns false for UHF NDBs or other beacons not receivable by a standard
   automatic direction finder (ADF) set.
   */
  public var isNDB: Bool {
    type == .NDB || type == .NDBDME
  }

  init(
    id: String,
    name: String,
    type: Self.FacilityType,
    city: String,
    stateName: String?,
    FAARegion: String,
    country: String?,
    ownerName: String?,
    operatorName: String?,
    commonSystemUsage: Bool,
    publicUse: Bool,
    navaidClass: Self.NavaidClass?,
    hoursOfOperation: String?,
    highAltitudeARTCCCode: String?,
    lowAltitudeARTCCCode: String?,
    position: Location,
    TACANPosition: Location?,
    surveyAccuracy: Self.SurveyAccuracy?,
    magneticVariationDeg: Int?,
    magneticVariationEpochComponents: DateComponents?,
    simultaneousVoice: Bool?,
    powerOutputW: UInt?,
    automaticVoiceId: Bool?,
    monitoringCategory: Self.MonitoringCategory?,
    radioVoiceCall: String?,
    tacanChannel: Self.TACANChannel?,
    frequencyKHz: UInt?,
    beaconIdentifier: String?,
    fanMarkerType: Self.FanMarkerType?,
    fanMarkerMajorBearing: Bearing<UInt>?,
    VORServiceVolume: Self.ServiceVolume?,
    DMEServiceVolume: Self.ServiceVolume?,
    lowAltitudeInHighStructure: Bool?,
    ZMarkerAvailable: Bool?,
    TWEBHours: String?,
    TWEBPhone: String?,
    controllingFSSCode: String?,
    NOTAMAccountabilityCode: String?,
    LFRLegs: [LFRLeg]?,
    status: OperationalStatus,
    isPitchPoint: Bool?,
    isCatchPoint: Bool?,
    isAssociatedWithSUA: Bool?,
    hasRestriction: Bool?,
    broadcastsHIWAS: Bool?,
    hasTWEBRestriction: Bool?,
    remarks: [String] = [String](),
    associatedFixes: Set<String> = Set<String>(),
    associatedHoldingPatterns: Set<HoldingPatternId> = Set<HoldingPatternId>(),
    fanMarkers: Set<String> = Set<String>(),
    checkpoints: [VORCheckpoint] = [VORCheckpoint]()
  ) {
    self.id = id
    self.name = name
    self.type = type
    self.city = city
    self.stateName = stateName
    self.FAARegion = FAARegion
    self.country = country
    self.ownerName = ownerName
    self.operatorName = operatorName
    self.commonSystemUsage = commonSystemUsage
    self.publicUse = publicUse
    self.navaidClass = navaidClass
    self.hoursOfOperation = hoursOfOperation
    self.highAltitudeARTCCCode = highAltitudeARTCCCode
    self.lowAltitudeARTCCCode = lowAltitudeARTCCCode
    self.position = position
    self.TACANPosition = TACANPosition
    self.surveyAccuracy = surveyAccuracy
    self.magneticVariationDeg = magneticVariationDeg
    self.magneticVariationEpochComponents = magneticVariationEpochComponents
    self.simultaneousVoice = simultaneousVoice
    self.powerOutputW = powerOutputW
    self.automaticVoiceId = automaticVoiceId
    self.monitoringCategory = monitoringCategory
    self.radioVoiceCall = radioVoiceCall
    self.tacanChannel = tacanChannel
    self.frequencyKHz = frequencyKHz
    self.beaconIdentifier = beaconIdentifier
    self.fanMarkerType = fanMarkerType
    self.fanMarkerMajorBearing = fanMarkerMajorBearing
    self.VORServiceVolume = VORServiceVolume
    self.DMEServiceVolume = DMEServiceVolume
    self.lowAltitudeInHighStructure = lowAltitudeInHighStructure
    self.ZMarkerAvailable = ZMarkerAvailable
    self.TWEBHours = TWEBHours
    self.TWEBPhone = TWEBPhone
    self.controllingFSSCode = controllingFSSCode
    self.NOTAMAccountabilityCode = NOTAMAccountabilityCode
    self.LFRLegs = LFRLegs
    self.status = status
    self.isPitchPoint = isPitchPoint
    self.isCatchPoint = isCatchPoint
    self.isAssociatedWithSUA = isAssociatedWithSUA
    self.hasRestriction = hasRestriction
    self.broadcastsHIWAS = broadcastsHIWAS
    self.hasTWEBRestriction = hasTWEBRestriction
    self.remarks = remarks
    self.associatedFixNames = associatedFixes
    self.associatedHoldingPatterns = associatedHoldingPatterns
    self.fanMarkers = fanMarkers
    self.checkpoints = checkpoints
  }

  public enum CodingKeys: String, CodingKey {
    case id, name, type, city, stateName, FAARegion, country, ownerName, operatorName,
      commonSystemUsage, publicUse, navaidClass, hoursOfOperation, highAltitudeARTCCCode,
      lowAltitudeARTCCCode, position, TACANPosition, surveyAccuracy, magneticVariationDeg,
      simultaneousVoice, powerOutputW, automaticVoiceId, monitoringCategory,
      radioVoiceCall, tacanChannel, frequencyKHz, beaconIdentifier, fanMarkerType,
      fanMarkerMajorBearing, VORServiceVolume, DMEServiceVolume, lowAltitudeInHighStructure,
      ZMarkerAvailable, TWEBHours, TWEBPhone, controllingFSSCode, NOTAMAccountabilityCode, LFRLegs,
      status, isPitchPoint, isCatchPoint, isAssociatedWithSUA, hasRestriction, broadcastsHIWAS,
      hasTWEBRestriction,
      remarks, associatedFixNames, associatedHoldingPatterns, fanMarkers, checkpoints
    case magneticVariationEpochComponents = "magneticVariationEpoch"
  }

  /// The types of navaid facilities provided by this class.
  public enum FacilityType: String, RecordEnum {

    /// A VOR and associated TACAN facility.
    case VORTAC = "VORTAC"

    /// A VOR and associated DME facility.
    case VORDME = "VOR/DME"

    /// A localizer marker beacon with an elongated reception cone.
    case fanMarker = "FAN MARKER"

    /// A Consolan transmitter (a long-range radio navigation system similar
    /// to Sonne or Consol.
    case consolan = "CONSOLAN"

    /// An NDB for marine use.
    case marineNDB = "MARINE NDB"

    /// An NDB/DME for marine use.
    case marineNDBDME = "MARINE NDB/DME"

    /// A VOR operational test facility. This is a VOR that transmits a
    /// fixed bearing signal of 180 TO, for purposes of testing receivers.
    case VOT = "VOT"

    /// A non-directional beacon, which transmits an omnidirectional signal.
    case NDB = "NDB"

    /// An NDB and associated DME facility.
    case NDBDME = "NDB/DME"

    /// A tactical air navigation facility, similar to a VOR but
    /// transmitting on UHF frequencies and intended for military use.
    case TACAN = "TACAN"

    /// An NDB that transmits on UHF frequencies.
    case UHFNDB = "UHF/NDB"

    /// A VHF omnidirectional range; a facility that transmits two phased
    /// signals for accurately determining bearing.
    case VOR = "VOR"

    /// Distance measuring equipment; a facility that aircraft radios can
    /// interrogate and use signal round-trip time to determine distance
    /// from the facility.
    case DME = "DME"

    /// A low-frequency radio range.
    case LFR = "LFR"

    // Single-character codes used in some NASR files (HPF, FSS, FIX, etc.)
    public static let synonyms: [String: Self] = [
      "C": .VORTAC,
      "D": .VORDME,
      "F": .fanMarker,
      "K": .consolan,
      "L": .LFR,
      "M": .marineNDB,
      "MD": .marineNDBDME,
      "O": .VOT,
      "OD": .DME,
      "R": .NDB,
      "RD": .NDBDME,
      "T": .TACAN,
      "U": .UHFNDB,
      "V": .VOR
    ]
  }

  /// A description of the capabilities of a navaid.
  public struct NavaidClass: Record {

    /// The altitude class.
    public internal(set) var altitude: AltitudeCode?

    /// The navaid class codes.
    public internal(set) var codes = Set<ClassCode>()

    public enum ClassCode: String, RecordEnum, CaseIterable {

      case automaticWeatherBroadcast = "AB"

      case DME = "DME"

      /// TACAN facility transmits on the Y-band (not X-band).
      case DMEYankeeBand = "DME(Y)"

      /// NDB transmission power between 50 and 2,000 watts (50 NM range).
      case NDBMediumPower = "H"

      /// NDB transmission power above 2,000 watts (75 NM range).
      case NDBHighPower = "HH"

      /// NDB with transcribed weather broadcast.
      case NDBWithTWEB = "SAB"

      /// Compass locator station functioning as a middle marker (15 NM
      /// range).
      case localizerMiddleMarker = "LMM"

      /// Compass locator station functioning as an outer marker (15 NM
      /// range).
      case localizerOuterMarker = "LOM"

      /// NDB transmission power below 50 watts (25 NM range).
      case NDBLowPower = "MH"

      /// Simultaneous range homing signal and/or voice.
      case simultaneousRangeHomingSignal = "S"

      /// NDB not authorized for use with IFR or by ATC, providing
      /// automatic weather broadcasts.
      case NDBNonIFRWithTWEB = "SABH"

      case TACAN = "TACAN"

      case VOR = "VOR"

      case VOT = "VOT"

      case VORTAC = "VORTAC"

      /// No voice capability on radio frequency.
      case noVoice = "W"

      /// Low-power station location marker associated with an airway
      /// marker.
      case VHFStationMarker = "Z"

      /// Canadian facility with ATIS capability.
      case ATIS = "A"

      /// Canadian facility with TWEB capability.
      case TWEB = "C"

      /// Canadian facility with scheduled weather broadcasts.
      case scheduledWeatherBroadcast = "B"

      /// Canadian facility where FSS can only receive on this frequency.
      case FSSTransmitOnly = "T"

      /// Canadian facility providing backup precision approach radar
      /// frequency.
      case PARBackup = "P"

      /// Transmits on the FM radio band.
      case FM = "FM"
    }

    /// Indicates what altitude ranges a facility is intended to be used
    /// with.
    public enum AltitudeCode: String, CaseIterable, RecordEnum {

      /// Intended for use up to 60,000 feet.
      case high = "H"

      /// Intended for use up to 18,000 feet.
      case low = "L"

      /// Intended for use up to 12,000 feet.
      case terminal = "T"
    }
  }

  /// Indicates the airspace volume the facility should be receivable within.
  public enum ServiceVolume: String, Record {

    /// Receivable up to 60,000 feet and out to 130 NM (though radius varies
    /// with altitude).
    case high = "H"

    /// Receivable up to 18,000 feet and out to 40 NM.
    case low = "L"

    /// Receivable up to 12,000 feet and out to 12 NM.
    case terminal = "T"

    /**
     Receivable up to 60,000 feet and out to 130 NM. The exact dimensions
     depend on whether the facility is a VOR or DME. This is the new service
     volume definition that the FAA introduced in 2020.
     */
    case navaidHigh = "NH"

    /**
     Receivable up to 18,000 feet and out to 70 NM (VORs) or 130 NM (DMEs).
     This is the new service volume definition that the FAA introduced in
     2020.
     */
    case navaidLow = "NL"
  }

  /// A measure of how accurately a navaid's location was surveyed.
  public enum SurveyAccuracy: Record {

    case unknown

    /**
     The location is accurate to within a given angular distance.
    
     - Parameter seconds: The accuracy in arc-seconds (e.g., a survey
                          accurate to one degree would be 3600 seconds).
     */
    case seconds(_ seconds: UInt)

    case NOS

    case thirdOrderTriangulation
  }

  /// The status of a navaid's monitoring system.
  public enum MonitoringCategory: String, RecordEnum {

    /// Internal monitoring available plus a status indicator installed at
    /// the control point.
    case statusOK = "1"

    /// Internal monitoring inoperative but pilot reports indicate facility
    /// is operable.
    case statusInopPilotReportsOK = "2"

    /// Internal monitoring but no status indication at control point, or
    /// status indication is inoperative.
    case internalMonitoringOnly = "3"

    /// No internal monitoring, but status indication is present at control
    /// point.
    case statusOnly = "4"
  }

  /// The channel and band that a TACAN station transmits on.
  public struct TACANChannel: Record {

    /// The transmission channel (1-126). Each channel corresponds to a
    /// specific UHF frequency for a given band.
    public let channel: UInt8

    /// The transmission band. Each band assigns its own set of frequencies
    /// to the channel numbers.
    public let band: Band

    /// TACAN frequency bands.
    public enum Band: String, RecordEnum {

      /// Channels in the X-ray band are from 962 to 1087 MHz in 1-MHz
      /// increments.
      case X

      /// Channels in the Yankee band are from 1088 to 1213 MHz in 1-MHz
      /// increments.
      case Y
    }
  }

  /// The shapes of a fan marker's service volume.
  public enum FanMarkerType: String, RecordEnum {

    /// A bone-shaped service volume has a narrow reception range at the
    /// center of the minor axis (i.e., centered along the airway), getting
    /// wider the further from the center the receiver is.
    case bone = "BONE"

    /// An elliptical service volume has a wide reception range at the
    /// center of the minor axis (i.e., centered along the airway), getting
    /// narrower the further from the center the receiver is.
    case elliptical = "ELLIPTICAL"
  }
}

/// A checkpoint is an identifiable location with known bearings from two or
/// more navigational facilities. The checkpoint can be used to cross-check
/// navigation receivers for accuracy.
public struct VORCheckpoint: Record {

  public let type: CheckpointType

  /// The bearing from the navaid to the checkpoint (for VOTs, this is the
  /// radial that should be received at the checkpoint).
  public let bearing: Bearing<UInt>

  /// The altitude of the checkpoint, when the checkpoint is airborne
  /// (feet MSL).
  public let altitudeFtMSL: Int?

  let airportId: String?
  let stateCode: String

  /// Narrative description of the airborne checkpoint.
  public let airDescription: String?

  /// Narrative description of the ground-based checkpoint.
  public let groundDescription: String?

  // for loading states from the parent FSS object
  var findStateByCode: (@Sendable (_ code: String) async -> State?)!

  // for loading states from the parent FSS object
  var findAirportById: (@Sendable (_ id: String) async -> Airport?)!

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(type, forKey: .type)
    try container.encode(bearing, forKey: .bearing)
    try container.encode(altitudeFtMSL, forKey: .altitudeFtMSL)
    try container.encode(airportId, forKey: .airportId)
    try container.encode(stateCode, forKey: .stateCode)
    try container.encode(airDescription, forKey: .airDescription)
    try container.encode(groundDescription, forKey: .groundDescription)
  }

  /// The airport associated with the checkpoint.
  public func airport(data: NASRData) async -> Airport? {
    await data.airports?.first { $0.id == airportId }
  }

  public enum CodingKeys: String, CodingKey {
    case type, bearing, altitudeFtMSL, airportId, stateCode, airDescription, groundDescription
  }

  public enum CheckpointType: String, RecordEnum {

    /// A checkpoint intended to be used while airborne.
    case air = "A"

    /// A checkpoint intended to be used from the ground.
    case ground = "G"

    case ground1 = "G1"
  }
}

/// A unique identifier of a holding pattern.
public struct HoldingPatternId: ParentRecord {

  /// The name of the facility or fix that anchors this holding pattern.
  public let name: String

  /// A number that uniquely identifies this holding pattern within the scope
  /// of ``name``.
  public let number: UInt

  public var id: String { "\(name).\(number)" }
}

/// A leg between two quadrants of a low-frequency range (LFR) system. The LFR
/// consists of four directional transmitters that together define four quadrants
/// (each labeled "A" or "N"). Aircraft are able to navigate on the legs where each
/// of the quadrants meet.
///
/// LFR quadrants are defined clockwise by their legs — in other words, a leg
/// oriented 360° and labeled "N" means the "N" quadrant spans from 360° to 90°
/// around the LFR station.
public struct LFRLeg: Record {

  /// The quadrant identifier clockwise from this leg.
  public let quadrant: Quadrant

  /// The bearing of this leg from the facility.
  public let bearing: Bearing<UInt>

  /**
   A quadrant is defined by its Morse code identifier. When an aircraft is
   between two quadrants, its Morse code identifiers overlap to produce a
   solid tone.
   */
  public enum Quadrant: String, RecordEnum {

    /// An "A" quadrant transmits "dit-dah".
    case A

    /// An "N" quadrant transmits "dah-dit".
    case N
  }
}
