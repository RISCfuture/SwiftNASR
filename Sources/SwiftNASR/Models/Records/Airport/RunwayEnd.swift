import Foundation

/**
  A runway "end" is a direction of a runway used for taking off or landing
 aircraft. Typical airport runways have two ends, called the base end and
 reciprocal end. (Which end is which is chosen arbitrarily.) Helipads and
 one-way runways have only one end, the base end.
 */

public struct RunwayEnd: Record {
  // MARK: - Properties

  /// The name of the runway direction, for example "29" for the northwest
  /// direction of runway "11/29".
  public let id: String

  /// The runway heading.
  public let heading: Bearing<UInt>?

  /// The type of instrument landing equipment available.
  public let instrumentLandingSystem: InstrumentLandingSystem?

  /// `true` if the traffic pattern for this runway uses right turns.
  public let rightTraffic: Bool?

  /// The runway markings.
  public let marking: Marking?

  /// The condition of the runway markings.
  public let markingCondition: MarkingCondition?

  /// The location and elevation of the physical runway end.
  public let threshold: Location?

  /// The height of the visual glidepath above the runway threshold (feet AGL).
  public let thresholdCrossingHeightFtAGL: UInt?

  /// The glidepath angle for a visual approach (degrees).
  public let visualGlidepathDeg: Float?

  /// The location and elevation of the displaced threshold, which is the
  /// start of the landing portion of the runway.
  public let displacedThreshold: Location?

  /// The distance between the runway end and displaced threshold (feet).
  public let thresholdDisplacementFt: UInt?

  /// The highest elevation within the touchdown zone (feet MSL).
  public let touchdownZoneElevationFtMSL: Float?

  /// The slope between the approach and departure ends of the runway
  /// (percent). A positive value indicates a runway that slopes up towards
  /// the reciprocal end.
  public let gradientPct: Float?

  /// The takeoff run available; the portion of the runway available for a
  /// takeoff roll and rotation (feet).
  public let TORAFt: UInt?

  /// Takeoff distance available; the portion of the runway and clearway
  /// beyond available for a takeoff and climb to 35 feet AGL (feet).
  public let TODAFt: UInt?

  /// Accelerate-stop distance available; the portion of the runway and
  /// stopway beyond available for an aborted takeoff (feet).
  public let ASDAFt: UInt?

  /// Landing distance available; the portion of the runway available for
  /// landing and rollout (feet).
  public let LDAFt: UInt?

  /// A location used for land-and-hold-short operations.
  public internal(set) var LAHSO: LAHSOPoint?

  /// Visual glideslope indicating equipment available.
  public let visualGlideslopeIndicator: VisualGlideslopeIndicator?

  /// Runway visibility range sensors available.
  public let RVRSensors: [RVRSensor]

  /// `true` if the runway has runway visibility value equipment.
  public let hasRVV: Bool?

  /// Type of approach lighting available.
  public let approachLighting: ApproachLighting?

  /// `true` if the runway has runway edge identification lights.
  public let hasREIL: Bool?

  /// `true` if the runway has centerline lighting.
  public let hasCenterlineLighting: Bool?

  /// `true` if the runway has runway end touchdown lights.
  public let hasEndTouchdownLighting: Bool?

  /// The obstacle that contributes most to raising the runway's approach
  /// slope.
  public internal(set) var controllingObject: ControllingObject?

  /// The source for the threshold position information.
  public let positionSource: String?

  /// The date the threshold position was determined.
  public let positionSourceDateComponents: DateComponents?

  /// The source for the threshold elevation information.
  public let elevationSource: String?

  /// The date the threshold elevation was determined.
  public let elevationSourceDateComponents: DateComponents?

  /// The source for the displaced threshold position information.
  public let displacedThresholdPositionSource: String?

  /// The date the displaced threshold position was determined.
  public let displacedThresholdPositionSourceDateComponents: DateComponents?

  /// The source for the displaced threshold elevation information.
  public let displacedThresholdElevationSource: String?

  /// The date the displaced threshold elevation was determined.
  public let displacedThresholdElevationSourceDateComponents: DateComponents?

  /// The source for the TDZE information.
  public let touchdownZoneElevationSource: String?

  /// The date the TDZE was determined.
  public let touchdownZoneElevationSourceDateComponents: DateComponents?

  /// The arresting equipment available on this runway.
  public internal(set) var arrestingSystems = [String]()

  /// General and per-field remarks.
  public internal(set) var remarks = Remarks<Field>()

  // MARK: - Methods

  init(
    id: String,
    heading: Bearing<UInt>?,
    instrumentLandingSystem: Self.InstrumentLandingSystem?,
    rightTraffic: Bool?,
    marking: Self.Marking?,
    markingCondition: Self.MarkingCondition?,
    threshold: Location?,
    thresholdCrossingHeightFtAGL: UInt?,
    visualGlidepathDeg: Float?,
    displacedThreshold: Location?,
    thresholdDisplacementFt: UInt?,
    touchdownZoneElevationFtMSL: Float?,
    gradientPct: Float?,
    TORAFt: UInt?,
    TODAFt: UInt?,
    ASDAFt: UInt?,
    LDAFt: UInt?,
    LAHSO: Self.LAHSOPoint?,
    visualGlideslopeIndicator: Self.VisualGlideslopeIndicator?,
    RVRSensors: [Self.RVRSensor],
    hasRVV: Bool?,
    approachLighting: Self.ApproachLighting?,
    hasREIL: Bool?,
    hasCenterlineLighting: Bool?,
    hasEndTouchdownLighting: Bool?,
    controllingObject: Self.ControllingObject?,
    positionSource: String?,
    positionSourceDateComponents: DateComponents?,
    elevationSource: String?,
    elevationSourceDateComponents: DateComponents?,
    displacedThresholdPositionSource: String?,
    displacedThresholdPositionSourceDateComponents: DateComponents?,
    displacedThresholdElevationSource: String?,
    displacedThresholdElevationSourceDateComponents: DateComponents?,
    touchdownZoneElevationSource: String?,
    touchdownZoneElevationSourceDateComponents: DateComponents?
  ) {
    self.id = id
    self.heading = heading
    self.instrumentLandingSystem = instrumentLandingSystem
    self.rightTraffic = rightTraffic
    self.marking = marking
    self.markingCondition = markingCondition
    self.threshold = threshold
    self.thresholdCrossingHeightFtAGL = thresholdCrossingHeightFtAGL
    self.visualGlidepathDeg = visualGlidepathDeg
    self.displacedThreshold = displacedThreshold
    self.thresholdDisplacementFt = thresholdDisplacementFt
    self.touchdownZoneElevationFtMSL = touchdownZoneElevationFtMSL
    self.gradientPct = gradientPct
    self.TORAFt = TORAFt
    self.TODAFt = TODAFt
    self.ASDAFt = ASDAFt
    self.LDAFt = LDAFt
    self.LAHSO = LAHSO
    self.visualGlideslopeIndicator = visualGlideslopeIndicator
    self.RVRSensors = RVRSensors
    self.hasRVV = hasRVV
    self.approachLighting = approachLighting
    self.hasREIL = hasREIL
    self.hasCenterlineLighting = hasCenterlineLighting
    self.hasEndTouchdownLighting = hasEndTouchdownLighting
    self.controllingObject = controllingObject
    self.positionSource = positionSource
    self.positionSourceDateComponents = positionSourceDateComponents
    self.elevationSource = elevationSource
    self.elevationSourceDateComponents = elevationSourceDateComponents
    self.displacedThresholdPositionSource = displacedThresholdPositionSource
    self.displacedThresholdPositionSourceDateComponents =
      displacedThresholdPositionSourceDateComponents
    self.displacedThresholdElevationSource = displacedThresholdElevationSource
    self.displacedThresholdElevationSourceDateComponents =
      displacedThresholdElevationSourceDateComponents
    self.touchdownZoneElevationSource = touchdownZoneElevationSource
    self.touchdownZoneElevationSourceDateComponents = touchdownZoneElevationSourceDateComponents
  }

  // MARK: - Types

  /// Visual glideslope indicating (VGSI) equipment.
  public struct VisualGlideslopeIndicator: Record {

    /// The type of VGSI.
    public let type: Classification

    /// The number of lights (for PAPIs or VASIs) or panels (for panel
    /// systems).
    public let number: UInt?

    /// The side of the runway the VGSI is on.
    public let side: Side?

    init(
      type: RunwayEnd.VisualGlideslopeIndicator.Classification,
      number: UInt? = nil,
      side: RunwayEnd.VisualGlideslopeIndicator.Side? = nil
    ) {
      self.type = type
      self.number = number
      self.side = side
    }

    /// VGSI types.
    public enum Classification: String, Record {

      /// Simplified abbreviated visual approach slope indicator
      case SAVASI = "SAVASI"

      /// Visual approach slope indicator
      case VASI = "VASI"

      /// Precision approach path indicator
      case PAPI = "PAPI"

      /// Any nonstandard glideslope indicating system
      case nonstandard = "NSTD"

      /// Privately-owned VGSI on a public airport, intended for private
      /// use only
      case `private` = "PVT"

      /// VASI with unspecified configuration
      case nonspecificVASI = "VAS"

      /// Tri-color VASI
      case tricolorVASI = "TRI"

      /// Pulsating/steady-burning VASI
      case pulsatingVASI = "PSI"

      /// A system of panels used for alignment
      case panels = "PNL"
    }

    /// The side(s) of the runway a VGSI is on.
    public enum Side: String, RecordEnum {
      case left = "L"
      case right = "R"
      case both = "B"
    }

    private enum CodingKeys: String, CodingKey {
      case type, number, side
    }
  }

  /// An obstacle or group of obstacles whose location and height affects the
  /// approach path to a runway.
  public struct ControllingObject: Record {

    /// The type of obstacle.
    public let category: Category

    /// How the obstacle is marked.
    public let markings: [Marking]

    /// FAR part 77 runway category.
    public let runwayCategory: String?

    /// Clearance slope, as _x_:1. Slopes greater than 50:1 are coded as 50.
    public let clearanceSlopeRatio: UInt?

    /// Obstacle height above runway surface (feet AGL).
    public let heightAboveRunwayFtAGL: UInt?

    /// Obstacle distance from runway threshold (feet).
    public let distanceFromRunwayFt: UInt?

    /// Obstacle offset from extended runway centerline.
    public let offsetFromCenterline: Offset?

    /// General and per-field remarks.
    public internal(set) var remarks = Remarks<Field>()

    /// Obstacle categories.
    public enum Category: RecordEnum {
      public typealias RawValue = String

      case aircraft

      /// Antenna or mast
      case antenna

      /// Berm, dike, levee, or riverbank
      case berm

      case building
      case boat

      /// Bridge or overpass
      case bridge

      /// Brush, shrubs, or hedge
      case brush

      case crops
      case fence
      case terrain
      case hangar

      /// Hill, dune, rock pile, knoll, cliff, canyon wall, mountain,
      /// butte, or similar
      case hill
      case light

      /**
       Any obstacle not coded as one of the other categories.
      
       - Parameter value: The obstacle type.
       */
      case other(_ value: String? = nil)

      /// Power line, telephone line, etc.
      case utilityLine

      /// Power pole, telephone pole, lightpole, or flagpole
      case pole

      case road
      case railroad

      /// Sign or billboard
      case sign

      /// Smokestack or chimney
      case stack

      case tank

      /// Beacon, derrick, rig, transmitter, windmill, or water tower
      case tower

      /// Group of trees including a forest
      case trees

      /// Single tree
      case tree

      private static let otherValue = "OTHER"

      public var rawValue: String {
        switch self {
          case .aircraft: return "ACFT"
          case .antenna: return "ANT"
          case .berm: return "BERM"
          case .building: return "BLDG"
          case .boat: return "BOAT"
          case .bridge: return "BRDG"
          case .brush: return "BRUSH"
          case .crops: return "CROPS"
          case .fence: return "FENCE"
          case .terrain: return "GND"
          case .hangar: return "HANGAR"
          case .hill: return "HILL"
          case .light: return "LIGHT"
          case .utilityLine: return "PLINE"
          case .pole: return "POLE"
          case .road: return "ROAD"
          case .railroad: return "RR"
          case .sign: return "SIGN"
          case .stack: return "STACK"
          case .tank: return "TANK"
          case .tower: return "TOWER"
          case .trees: return "TREES"
          case .tree: return "TREE"
          case .other(let value): return value ?? Self.otherValue
        }
      }

      public init(rawValue: String) {
        switch rawValue {
          case "ACFT": self = .aircraft
          case "ANT": self = .antenna
          case "BERM": self = .berm
          case "BLDG": self = .building
          case "BOAT": self = .boat
          case "BRDG": self = .bridge
          case "BRUSH": self = .brush
          case "CROPS": self = .crops
          case "FENCE": self = .fence
          case "GND": self = .terrain
          case "HANGAR": self = .hangar
          case "HILL": self = .hill
          case "LIGHT": self = .light
          case "PLINE": self = .utilityLine
          case "POLE": self = .pole
          case "ROAD": self = .road
          case "RR": self = .railroad
          case "SIGN": self = .sign
          case "STACK": self = .stack
          case "TANK": self = .tank
          case "TOWER": self = .tower
          case "TREES": self = .trees
          case "TREE": self = .tree
          default: self = .other(rawValue)
        }
      }

      public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = Self(rawValue: try container.decode(String.self))
      }

      public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
      }
    }

    /// Methods by which an obstacle can be marked.
    public enum Marking: String, RecordEnum {

      /// Obstacle has visible markings such as paint.
      case marked = "M"

      /// Obstacle is lighted at night.
      case lighted = "L"
    }

    /// Fields that per-field remarks can be associated with.
    public enum Field: String, RemarkField {
      case category, markings, runwayCategory, clearanceSlopeRatio, heightAboveRunwayFtAGL,
        distanceFromRunwayFt, offsetFromCenterline

      static var fieldOrder: [Self?] {
        var order = [Self?](repeating: nil, count: 37)
        order.append(contentsOf: [
          .category, .markings, .clearanceSlopeRatio, .heightAboveRunwayFtAGL,
          .distanceFromRunwayFt,
          .distanceFromRunwayFt, .offsetFromCenterline
        ])
        order.append(contentsOf: Array(repeating: nil, count: 27))
        order.append(contentsOf: [
          .category, .markings, .clearanceSlopeRatio, .heightAboveRunwayFtAGL,
          .distanceFromRunwayFt,
          .distanceFromRunwayFt, .offsetFromCenterline
        ])
        order.append(contentsOf: Array(repeating: nil, count: 57))
        return order
      }
    }

    private enum CodingKeys: String, CodingKey {
      case category, markings, runwayCategory, clearanceSlopeRatio, heightAboveRunwayFtAGL,
        distanceFromRunwayFt, offsetFromCenterline
    }
  }

  /// A location on the runway that aircraft are expected to stop before when
  /// land-and-hold-short operations are in effect.
  public struct LAHSOPoint: Record {

    /// The distance from the landing threshold to the LAHSO point (feet).
    public let availableDistanceFt: UInt

    /// The identifier of the intersecting runway defining the LAHSO point,
    /// if defined by runway.
    public let intersectingRunwayId: String?

    /// A description of the intersecting entity defining the LAHSO point,
    /// if not a runway (e.g., a taxiway).
    public let definingEntity: String?

    /// The location of the LAHSO hold-short point.
    public let position: Location?

    /// The source for the position information.
    public let positionSource: String?

    /// The date the position was determined.
    public let positionSourceDateComponents: DateComponents?

    /// General and per-field remarks.
    public internal(set) var remarks = Remarks<Field>()

    // for accessing other runways in the parent Airport
    var findRunwayById: (@Sendable (_ runwayId: String) -> Runway?)!

    /// Fields that per-field remarks can be associated with.
    public enum Field: String, RemarkField {
      case availableDistanceFt, intersectingRunwayId, definingEntity, position, positionSource,
        positionSourceDate

      static var fieldOrder: [Self?] {
        var order = [Self?](repeating: nil, count: 100)
        order.append(contentsOf: [
          .availableDistanceFt, .intersectingRunwayId, .position, .position, .position, .position,
          .positionSource, .positionSourceDate
        ])
        order.append(contentsOf: Array(repeating: nil, count: 16))
        order.append(contentsOf: [
          .availableDistanceFt, .intersectingRunwayId, .position, .position, .position, .position,
          .positionSource, .positionSourceDate, nil
        ])
        return order
      }
    }

    private enum CodingKeys: String, CodingKey {
      case availableDistanceFt, intersectingRunwayId, definingEntity, position, positionSource
      case positionSourceDateComponents = "positionSourceDate"
    }
  }

  // MARK: - Enums

  /// Instrument landing equipment.
  public enum InstrumentLandingSystem: String, RecordEnum {

    /// Instrument landing system
    case ILS = "ILS"

    /// Microwave landing system
    case MLS = "MLS"

    /// Simplified directional facility
    case SDF = "SDF"

    /// Localizer only (no glideslope)
    case localizer = "LOCALIZER"

    /// Localizer-type directional aid (localizer not aligned with approach
    /// heading)
    case LDA = "LDA"

    /// Interim standard microwave landing system
    case interimStandardMLS = "ISMLS"

    /// ILS with distance measuring equipment
    case ILS_DME = "ILS/DME"

    /// SDF with distance measuring equipment
    case SDF_DME = "SDF/DME"

    /// Localizer with distance measuring equipment
    case LOC_DME = "LOC/DME"

    /// LDA with distance measuring equipment
    case LDA_DME = "LDA/DME"

    static let synonyms: [RawValue: Self] = [
      "LOC/GS": .ILS
    ]
  }

  /// Runway end markings (typically painted on the runway)
  /// (see AC 150/5340-1).
  public enum Marking: String, RecordEnum {

    /// Designation, centerline, threshold, aimpoint, touchdown zone, and
    /// side stripe markings.
    case precisionInstrument = "PIR"

    /// Designation, centerline, threshold, and aimpoint markings.
    case nonprecisionInstrument = "NPI"

    /// Designation and centerline markings (plus threshold for runways used
    /// by international air transport, plus aimpoint for runways > 4,000
    /// feet long used by jet aircraft).
    case basic = "BSC"

    /// Designation only
    case numbers = "NRS"

    /// Markings other than those specified by AC 150/5430-1.
    case nonstandard = "NSTD"

    /// Buoys indicating the edges of a water runway.
    case buoys = "BUOY"

    /// The word "STOL" (short takeoff and landing) is painted on the
    /// approach end.
    case STOL = "STOL"
  }

  /// Visible condition of markings.
  public enum MarkingCondition: String, RecordEnum {
    case good = "G"
    case fair = "F"
    case poor = "P"

    static let synonyms: [RawValue: Self] = [
      "GOOD": .good,
      "FAIR": .fair,
      "POOR": .poor
    ]
  }

  /// Location of runway visual range sensors.
  public enum RVRSensor: String, RecordEnum {

    /// Located 0 to 2500 feet from the approach end runway threshold,
    /// normally behind the ILS or VGSI equipment.
    case touchdown = "T"

    /// Located ±1000 feet from the runway centerpoint.
    case midpoint = "M"

    /// Located 0 to 2500 feet from the departure end runway threshold,
    /// normally behind the ILS or VGSI equipment.
    case rollout = "R"
  }

  /// Approach lighting equipment.
  public enum ApproachLighting: String, RecordEnum {

    /// 3000-foot high-intensity approach lighting system with centerline
    /// sequenced flashers
    case ALSAF = "ALSAF"

    /// Unspecified ALSF system (either ALSF-1 or ALSF-2)
    case ALSF = "ALSF"

    /// Standard 2400-foot high-intensity approach lighting system with
    /// sequenced flashers, category I configuration
    case ALSF1 = "ALSF1"

    /// Standard 2400-foot high-intensity approach lighting system with
    /// sequenced flashers, category II or III configuration
    case ALSF2 = "ALSF2"

    /// 1400-foot medium intensity approach lighting system
    case MALS = "MALS"

    /// MALS with sequenced flashers
    case MALSF = "MALSF"

    /// MALS with runway alignment indicator lights
    case MALSR = "MALSR"

    /// Simplifed short approach lighting system
    case SSALS = "SSALS"

    /// SSALS with sequenced flashers
    case SSALF = "SSALF"

    /// SSALS with runway alignment indicator lights
    case SSALR = "SSALR"

    /// Neon ladder lighting system
    case neonLadder = "NEON"

    /// Omnidirectional approach lighting system
    case ODALS = "ODALS"

    /// Runway lead-in lighting system
    case RLLS = "RLLS"

    /// Runway alignment indicator lights
    case RAIL = "RAIL"

    /// Military overrun lighting
    case militaryOverrun = "MIL OVRN"

    /// Any other lighting configuration
    case nonstandard = "NSTD"

    static let synonyms: [RawValue: Self] = [
      "AFOVRN": .militaryOverrun, "MIL_OVRN": .militaryOverrun,
      "SALS": .SSALS,
      "SALSF": .SSALF
    ]
  }

  /// Fields that per-field remarks can be associated with.
  public enum Field: String, RemarkField {
    case id, heading, instrumentLandingSystem, rightTraffic, marking, markingCondition,
      threshold, thresholdCrossingHeightFtAGL, visualGlidepathDeg, displacedThreshold,
      thresholdDisplacementFt, touchdownZoneElevationFtMSL, gradientPct, TORAFt, TODAFt, ASDAFt,
      LDAFt, LAHSO,
      visualGlideslopeIndicator, RVRSensors, hasRVV, approachLighting, hasREIL,
      hasCenterlineLighting, hasEndTouchdownLighting, controllingObject, positionSource,
      positionSourceDate, elevationSource, elevationSourceDate, displacedThresholdPositionSource,
      displacedThresholdPositionSourceDate, displacedThresholdElevationSource,
      displacedThresholdElevationSourceDate, touchdownZoneElevationSource,
      touchdownZoneElevationSourceDate

    case arrestingSystems

    static var fieldOrder: [Self?] {
      var order = [Self?](repeating: nil, count: 10)
      for _ in 1...2 {
        order.append(contentsOf: [
          .id, .heading, .instrumentLandingSystem, .rightTraffic, .marking, .markingCondition,
          .threshold, .threshold, .threshold, .threshold, .threshold, .thresholdCrossingHeightFtAGL,
          .visualGlidepathDeg, .displacedThreshold, .displacedThreshold,
          .displacedThreshold,
          .displacedThreshold, .displacedThreshold, .thresholdDisplacementFt,
          .touchdownZoneElevationFtMSL,
          visualGlideslopeIndicator, .RVRSensors, .hasRVV, approachLighting, .hasREIL,
          .hasCenterlineLighting, .hasEndTouchdownLighting,
          .controllingObject, .controllingObject, .controllingObject, .controllingObject,
          .controllingObject, .controllingObject, .controllingObject
        ])
      }
      order.append(contentsOf: Array(repeating: nil, count: 6))
      for _ in 1...2 {
        order.append(contentsOf: [
          .gradientPct, .gradientPct, .positionSource, .positionSourceDate, .elevationSource,
          .elevationSourceDate, .displacedThresholdPositionSource,
          .displacedThresholdPositionSourceDate, .displacedThresholdElevationSource,
          .displacedThresholdElevationSourceDate, .touchdownZoneElevationSource,
          .touchdownZoneElevationSourceDate, .TORAFt, .TODAFt, .ASDAFt, .LDAFt, .LAHSO, .LAHSO,
          .LAHSO,
          .LAHSO, .LAHSO, .LAHSO, .LAHSO, .LAHSO, .LAHSO
        ])
      }
      order.append(nil)
      return order
    }
  }

  private enum CodingKeys: String, CodingKey {
    case id, heading, instrumentLandingSystem, rightTraffic, marking, markingCondition,
      threshold, thresholdCrossingHeightFtAGL, visualGlidepathDeg, displacedThreshold,
      thresholdDisplacementFt, touchdownZoneElevationFtMSL, visualGlideslopeIndicator, RVRSensors,
      hasRVV,
      approachLighting, hasREIL, hasCenterlineLighting, hasEndTouchdownLighting, controllingObject,
      gradientPct, positionSource, elevationSource,
      displacedThresholdPositionSource,
      displacedThresholdElevationSource,
      touchdownZoneElevationSource, TORAFt, TODAFt, ASDAFt, LDAFt,
      LAHSO

    case positionSourceDateComponents = "positionSourceDate"
    case elevationSourceDateComponents = "elevationSourceDate"
    case displacedThresholdPositionSourceDateComponents = "displacedThresholdPositionSourceDate"
    case displacedThresholdElevationSourceDateComponents = "displacedThresholdElevationSourceDate"
    case touchdownZoneElevationSourceDateComponents = "touchdownZoneElevationSourceDate"

    case arrestingSystems, remarks
  }
}
