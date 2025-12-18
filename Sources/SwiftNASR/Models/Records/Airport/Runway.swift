import Foundation

/**
 A runway at an airport (or other surface used for taking off or landing
 aircraft, such as a helipad or waterway).

 Runways consist of one or two runway "ends" (``RunwayEnd``), which are
 directions along that runway that an aircraft can use to take off or land. A
 typical runway has two ends, called the base end and reciprocal end. Which is
 the base end is chosen arbitrarily. Helipads and one-way runways do not have a
 reciprocal end.
 */

public struct Runway: Record {

  // MARK: - Properties

  /// The unique name of the runway, such as "11/29" for a runway with two
  /// ends (runway 11 and runway 29), or "H-1" for a helipad.
  public let identification: String

  /// The total runway length, in feet.
  public let lengthFt: UInt?

  /// The runway width, in feet.
  public let widthFt: UInt?

  /// The source of the runway length data.
  public let lengthSource: String?

  /// The date the runway length was determined.
  public let lengthSourceDate: DateComponents?

  /// The materials that the runway is made from. Having multiple materials in
  /// this set indicates that the runway consists of multiple segments of
  /// different materials.
  public let materials: Set<Material>

  /// The condition of the runway surface.
  public let condition: Condition?

  /// The type of treatment or sealant used on the runway surface.
  public let treatment: Treatment?

  /// The weight-bearing classification of the runway pavement.
  public let pavementClassification: PavementClassification?

  /// The intensity of the runway edge lights.
  public let edgeLightsIntensity: EdgeLightIntensity?

  /// The runway base-end direction (or the only direction, for a helipad or
  /// one-way runway). This would be runway 29 for a runway labeled "29/11".
  public package(set) var baseEnd: RunwayEnd

  /// The runway reciprocal-end direction. This would be runway 11 for a
  /// runway labeled "29/11".
  public package(set) var reciprocalEnd: RunwayEnd?

  /// The maximum weight of an aircraft with single-wheel type landing gear
  /// (thousands of pounds; e.g., Douglas DC-3, F-15 Eagle).
  public let singleWheelWeightBearingCapacityKlb: UInt?

  /// The maximum weight of an aircraft with dual-wheel type landing gear
  /// (thousands of pounds; e.g., Beech 1900, Boeing 737, Airbus A319).
  public let dualWheelWeightBearingCapacityKlb: UInt?

  /// The maximum weight of an aircraft with two dual wheels in tandem type
  /// landing gear (thousands of pounds; e.g., Boeing 707).
  public let tandemDualWheelWeightBearingCapacityKlb: UInt?

  /// The maximum weight of an aircraft with two dual wheels in double tandem
  /// body gear (thousands of pounds; e.g., Boeing 747).
  public let doubleTandemDualWheelWeightBearingCapacityKlb: UInt?

  /// The remarks for this runway record and its fields.
  public internal(set) var remarks = Remarks<Field>()

  /// `true` if the runway consists entirely of paved materials (no dirt,
  /// turf, sand, water, etc.).
  public var isPaved: Bool {
    for material in materials {
      switch material {
        case .asphalt, .brick, .concrete, .deck, .gravel, .metal, .partiallyConcreteOrAsphalt,
          .piercedSteel, .roof:
          continue
        default:
          return false
      }
    }
    return true
  }

  /**
   Returns the estimated gradient of the runway, calculated using the base
   and reciprocal end TDZEs and the runway length. This value could be used in
   lieu of ``RunwayEnd/gradientPct`` if that data is unavailable. Returns `nil`
   if a necessary value is not present. A positive value indicates a runway
   that slopes up towards the reciprocal end.
   */
  public var estimatedGradientPct: Float? {
    guard let baseElevation = self.baseEnd.touchdownZoneElevationFtMSL,
      let reciprocalElevation = self.reciprocalEnd?.touchdownZoneElevationFtMSL,
      let runwayLength = self.lengthFt
    else { return nil }

    return (reciprocalElevation - baseElevation) / Float(runwayLength) * 100.0
  }

  // MARK: - Methods

  init(
    identification: String,
    lengthFt: UInt?,
    widthFt: UInt?,
    lengthSource: String?,
    lengthSourceDate: DateComponents?,
    materials: Set<Material>,
    condition: Condition?,
    treatment: Treatment?,
    pavementClassification: PavementClassification?,
    edgeLightsIntensity: EdgeLightIntensity?,
    baseEnd: RunwayEnd,
    reciprocalEnd: RunwayEnd?,
    singleWheelWeightBearingCapacityKlb: UInt?,
    dualWheelWeightBearingCapacityKlb: UInt?,
    tandemDualWheelWeightBearingCapacityKlb: UInt?,
    doubleTandemDualWheelWeightBearingCapacityKlb: UInt?
  ) {
    self.identification = identification
    self.lengthFt = lengthFt
    self.widthFt = widthFt
    self.lengthSource = lengthSource
    self.lengthSourceDate = lengthSourceDate
    self.materials = materials
    self.condition = condition
    self.treatment = treatment
    self.pavementClassification = pavementClassification
    self.edgeLightsIntensity = edgeLightsIntensity
    self.baseEnd = baseEnd
    self.reciprocalEnd = reciprocalEnd
    self.singleWheelWeightBearingCapacityKlb = singleWheelWeightBearingCapacityKlb
    self.dualWheelWeightBearingCapacityKlb = dualWheelWeightBearingCapacityKlb
    self.tandemDualWheelWeightBearingCapacityKlb = tandemDualWheelWeightBearingCapacityKlb
    self.doubleTandemDualWheelWeightBearingCapacityKlb =
      doubleTandemDualWheelWeightBearingCapacityKlb
  }

  // MARK: - Types

  /// A runway pavement classification number (PCN) and its attributes. See
  /// AC 150/5335-5 for detailed information on how PCN is calculated.
  public struct PavementClassification: Record {

    /// The determined PCN, a broad classification of runway strength.
    public let number: UInt

    /// Whether the rigid or flexible pavement method was used for the PCN
    /// calculation.
    public let type: Classification

    /// The standard subgrade strength category of the runway.
    public let subgradeStrengthCategory: SubgradeStrengthCategory

    /// The maximum allowable tire pressure.
    public let tirePressureLimit: TirePressureLimit

    /// The PCN determination method.
    public let determinationMethod: DeterminationMethod

    /// PCN pavement types, used to determine how the PCN is calculated.
    public enum Classification: String, RecordEnum {

      /// PCN is calculated for rigid pavements using the Westergaard
      /// theory.
      case rigid = "R"

      /// PCN is calculated for flexible pavements using the CBR design
      /// procedure combined with Boussinesq's solution.
      case flexible = "F"
    }

    /// Subgrade strength categories, standardized strengths of rigid or
    /// flexible pavements used to calculate the ACN (aircraft
    /// classification number).
    public enum SubgradeStrengthCategory: String, RecordEnum {

      /// Rigid pavements: Characterized by _K_ = 150 MN/m^3 and
      /// representing all _K_ values above 120 MN/m^3. Flexible
      /// pavements: Characterized by CBR = 15 and representing all CBR
      /// values above 13.
      case high = "A"

      /// Rigid pavements: Characterized by _K_ = 80 MN/m^3 and
      /// representing all _K_ values from 60 to 120 MN/m^3. Flexible
      /// pavements: Characterized by CBR = 10 and representing all CBR
      /// values from 8 to 13.
      case medium = "B"

      /// Rigid pavements: Characterized by _K_ = 40 MN/m^3 and
      /// representing all _K_ values from 25 to 60 MN/m^3. Flexible
      /// pavements: Characterized by CBR = 6 and representing all CBR
      /// values from 4 to 8.
      case low = "C"

      /// Rigid pavements: Characterized by _K_ = 20 MN/m^3 and
      /// representing all _K_ values below 25 MN/m^3. Flexible
      /// pavements: Characterized by CBR = 3 and representing all CBR
      /// values below 4.
      case ultralow = "D"
    }

    /// Maximum allowable tire pressure values.
    public enum TirePressureLimit: String, RecordEnum {

      /// No pressure limit.
      case unlimited = "W"

      /// Limited to 1.75 MPa.
      case high = "X"

      /// Limited to 1.25 MPa.
      case medium = "Y"

      /// Limited to 0.5 MPa.
      case low = "Z"
    }

    /// Methods by which PCN can be determined.
    public enum DeterminationMethod: String, RecordEnum {

      /// PCN was determined using aircraft.
      case aircraft = "U"

      /// PCN was determined using technical analysis.
      case technical = "T"
    }

    private enum CodingKeys: String, CodingKey {
      case number
      case type
      case subgradeStrengthCategory
      case tirePressureLimit
      case determinationMethod
    }
  }

  // MARK: - Enums

  /// Materials that a runway can be made from.
  public enum Material: String, RecordEnum {

    /// Concrete or Portland cement
    case concrete = "CONC"

    /// Asphalt, bituminous concrete, hot mix, road mix, macadam, or plant
    /// mix
    case asphalt = "ASPH"

    case snow = "SNOW"
    case ice = "ICE"
    case metal = "METAL"

    /// Pierced steel planking (PSP), pierced steel mats, or membrane
    case piercedSteel = "MATS"

    /// Treated, oiled, soil cement, lime-stabilized, paved roof, or
    /// coal-tar seal coat
    case treated = "TREATED"

    /// Gravel, cinders, crushed rock, coral, shells, slag, laterite, or
    /// shale
    case gravel = "GRVL"

    /// Grass or sod
    case turf = "TURF"

    /// Dirt, soil, adobe, bare, bladed, caliche, clay, earth, loam, or silt
    case dirt = "DIRT"

    case wood = "WOOD"
    case sand = "SAND"
    case brick = "BRICK"
    case nonstandard = "NSTD"
    case water = "WATER"
    case roof = "ROOF"
    case deck = "DECK"
    case partiallyConcreteOrAsphalt = "PEM"

    /// Graded or rolled earth
    case gradedOrRolledEarth = "GRE"

    /// Porous friction course (should be a treatment, but often shows up here)
    case PFC = "PFC"

    static let synonyms: [RawValue: Self] = [
      "GRAVEL": .gravel, "TRTD": .treated, "ALUMINUM": .metal,
      "STEEL": .metal, "OIL&CHIP": .treated, "CORAL": .gravel,
      "CALICHE": .gravel, "TOP": .roof, "PSP": .piercedSteel,
      "ROOFTOP": .roof, "ALUM": .metal, "GRASS": .turf, "SOD": .turf,
      "T": .treated
    ]
  }

  /// The condition of the runway surface.
  public enum Condition: String, RecordEnum {

    /// New pavement or pavement with no cracks or a few hairline cracks.
    case excellent = "E"

    /// Some cracking of the pavement. Cracks are generally spaced more than
    /// 50 feet apart. Fewer than 10% of the cracks and joints need sealing.
    /// There is minimal or slight raveling. There is no distortion, and the
    /// patches are in good condition.
    case good = "G"

    /// Some cracking and raveling. Cracks are generally spaced less than 50
    /// feet apart. Joint and crack sealing is needed on 10% to 25% of the
    /// cracks and joints. There is isolated alligator cracking, the patches
    /// are in poor condition, and/or there are crack settlements up to 1
    /// inch.
    case fair = "F"

    /// Widespread, open, unsealed cracks and joints. There are cracks over
    /// one-half inch wide with raveling in 25% of the cracks. Cracks are
    /// generally spaced 5 to 50 feet apart with surface and slab spalling.
    /// Alligator cracking or patches are in poor condition and cover up to
    /// 20% of the surface or there is vegetation through the cracks and
    /// joints.
    case poor = "P"

    /// Widespread severe cracking and distortion over 2 inches. Alligator
    /// cracking over 20% or more and widespread vegetation growth in the
    /// pavement cracks. Slabs are extensively cracked and shattered with
    /// severe spalling and faulting over one half inch.
    case failed = "L"

    static let synonyms: [RawValue: Self] = [
      "EXCELLENT": .excellent,
      "GOOD": .good,
      "FAIR": .fair,
      "POOR": .poor,
      "FAILED": .failed
    ]
  }

  /// Treatment applied to a runway surface.
  public enum Treatment: String, RecordEnum {

    /// Saw-cut or plastic grooved
    case grooved = "GRVD"

    /// Porous friction course
    case PFC = "PFC"

    /// Aggregate friction seal coat
    case AFSC = "AFSC"

    /// Rubberized friction seal coat
    case RFSC = "RFSC"

    /// Wire comb or wire tine
    case wireComb = "WC"
  }

  /// The intensity of runway edge lights.
  public enum EdgeLightIntensity: String, RecordEnum {
    case high = "HIGH"
    case medium = "MED"
    case low = "LOW"

    case nonstandard = "NSTD"

    /// (helipads only) Flood lights
    case flood = "FLOOD"

    /// (helipads only) Perimeter lighting
    case perimeter = "PERI"

    /// (helipads only) Strobe lighting
    case strobe = "STROBE"

    static let synonyms: [String: Runway.EdgeLightIntensity] = [
      "FLD": .flood, "STRB": .strobe
    ]
  }

  /// Fields that per-field remarks can be associated with.
  public enum Field: String, RemarkField {
    case identification, lengthFt, widthFt, lengthSource, lengthSourceDate, materials, condition,
      treatment, pavementClassification, edgeLightsIntensity, baseEnd, reciprocalEnd,
      singleWheelWeightBearingCapacityKlb, dualWheelWeightBearingCapacityKlb,
      tandemDualWheelWeightBearingCapacityKlb, doubleTandemDualWheelWeightBearingCapacityKlb

    static var fieldOrder: [Self?] {
      var order: [Self?] = [
        nil, nil, nil, .identification,
        .lengthFt, .widthFt, .materials, .treatment, .pavementClassification, .edgeLightsIntensity
      ]
      order.append(contentsOf: Array(repeating: .baseEnd, count: 34))
      order.append(contentsOf: Array(repeating: .reciprocalEnd, count: 34))
      order.append(contentsOf: [
        .lengthSource, .lengthSourceDate, .singleWheelWeightBearingCapacityKlb,
        .dualWheelWeightBearingCapacityKlb, .tandemDualWheelWeightBearingCapacityKlb,
        .doubleTandemDualWheelWeightBearingCapacityKlb
      ])
      order.append(contentsOf: Array(repeating: .baseEnd, count: 25))
      order.append(contentsOf: Array(repeating: .reciprocalEnd, count: 25))
      order.append(nil)
      return order
    }
  }

  private enum CodingKeys: String, CodingKey {
    case identification, lengthFt, widthFt, materials, condition, treatment, pavementClassification,
      edgeLightsIntensity, baseEnd, reciprocalEnd, lengthSource, lengthSourceDate,
      singleWheelWeightBearingCapacityKlb, dualWheelWeightBearingCapacityKlb,
      tandemDualWheelWeightBearingCapacityKlb, doubleTandemDualWheelWeightBearingCapacityKlb

    case remarks
  }
}
