import Foundation

/**
 A landing facility, including airports, seaports, heliports, balloonports, etc.
 
 The NASR data includes public airports, military and government airports, and
 private airports whose owners have opted to include their airport in the
 database. It includes all such airports in the USA and its territories, as well
 as a few non-US airports bordering the USA.
 
 For the annual operational statistics, an "operation" is defined as a takeoff
 or a landing.
 */

public class Airport: Record, Identifiable, Equatable, Codable, Hashable {

    // MARK: - Properties

    /// A unique identifier for this airport. This field should be used to
    /// uniquely identify an airport, as the ``LID`` for an airport
    /// can sometimes change.
    public var id: String
    
    /// The airport name.
    public let name: String
    
    /// The three-character FAA identifier for the airport (e.g., "JFK").
    public let LID: String
    
    /// The four-letter ICAO identifier for the airport, if any (e.g., "KJFK").
    /// (ICAO identifiers are not always simply the FAA identifier prepended
    /// with the letter "K".)
    public let ICAOIdentifier: String?

    /// The airport type.
    public let facilityType: FacilityType

    // MARK: Demographics
    
    /// The FAA region the airport is located in.
    public let FAARegion: FAARegion?
    
    /// The code for the associated FAA district or field office.
    public let FAAFieldOfficeCode: String?
    
    /// The post office code of the state the airport is in.
    public let stateCode: String?
    
    /// The county associated with the airport.
    public let county: String
    
    /// The post office code of the state containing the associated county.
    public let countyStateCode: String
    
    /// The city associated with the airport.
    public let city: String

    // MARK: Ownership
    
    /// The type of ownership (public, private, etc.).
    public let ownership: Ownership
    
    /// `true` when the general public can use the airport without prior
    /// approval.
    public let publicUse: Bool
    
    /// The person or organization that owns the airport.
    public var owner: Person?
    
    /// The person or organization that manages the airport.
    public var manager: Person?

    // MARK: Geographics
    
    /// The location of the airport (specifically, the location of the ARP,
    /// which is typically the geographic center of all usable runway surfaces),
    /// and the airport elevation, which is the highest elevation of any usable
    /// runway surface (may not be the elevation of the ARP location).
    public let referencePoint: Location
    
    /// How the ARP was determined.
    public let referencePointDeterminationMethod: LocationDeterminationMethod
    
    /// How the airport elevation was determined.
    public let elevationDeterminationMethod: LocationDeterminationMethod?
    
    /// The variation between magnetic and true north.
    public let magneticVariation: Int?
    
    /// The epoch date of the World Magnetic Model that was used to determine
    /// the magnetic variation.
    public let magneticVariationEpoch: Date?
    
    /// The altitude at which aircraft should fly the traffic pattern. (If there
    /// separate TPAs for separate classes of aircraft, this will be indicated
    /// in the remarks for this field.
    public let trafficPatternAltitude: Int?
    
    /// The identifier for the sectional chart this airport appears in.
    public let sectionalChart: String?
    
    /// The distance from the airport to the central business district of the
    /// associated city.
    public let distanceCityToAirport: UInt?
    
    /// The direction from the airport to the central business district of the
    /// associated city.
    public let directionCityToAirport: Direction?
    
    /// The area of land occupied by this airport.
    public let landArea: Float?
    
    /// The source of ARP information.
    public let positionSource: String?
    
    /// The date at which the ARP was determined.
    public let positionSourceDate: Date?
    
    /// The source of airport elevation information.
    public let elevationSource: String?
    
    /// The date at which the airport elevation was determined.
    public let elevationSourceDate: Date?

    // MARK: FAA Services
    
    /// The identifier for the ARTCC overlying this airport.
    public let boundaryARTCCID: String
    
    /// The identifier for the ARTCC responsible for traffic to and from this
    /// airport.
    public let responsibleARTCCID: String
    
    /// The identifier for the tie-in flight service station responsible for
    /// this airport.
    public let tieInFSSID: String
    
    /// `true` if the tie-in FSS is located on the airport.
    public let tieInFSSOnStation: Bool?
    
    /// The identifier for an alternate FSS responsible for this airport when
    /// the tie-in FSS is closed.
    public let alternateFSSID: String?
    
    /// The identifier of the FSS responsible for issuing NOTAMs for this
    /// airport.
    public let NOTAMIssuerID: String?
    
    /// `true` if NOTAM Ds (distant NOTAMs) are available for this airport.
    public let NOTAMDAvailable: Bool?

    // MARK: Federal Status
    
    /// The date that the airport was first activated.
    public let activationDate: Date?
    
    /// The airport's current activation status.
    public let status: Status
    
    /// The on-airport firefighting capability.
    public let ARFFCapability: ARFFCapability?
    
    /// The federal land-use agreements covering this airport.
    public let agreements: Array<FederalAgreement>
    
    /// The determination by the FAA of how the airport affects local airspace.
    public let airspaceAnalysisDetermination: AirspaceAnalysisDetermination?
    
    /// `true` if this airport is a US CBP Airport of Entry, where travelers
    /// coming or returning from foreign countries can receive permission to
    /// enter the USA from the CBP.
    public let customsEntryAirport: Bool?
    
    /// `true` if international travelers arriving at this airport require prior
    /// landing rights granted to them by the CBP.
    public let customsLandingRightsAirport: Bool?
    
    /// `true` if this airport is governed by a joint civil-military use
    /// agreement.
    public let jointUseAgreement: Bool?
    
    /// `true` if the US military has landing rights at this airport.
    public let militaryLandingRights: Bool?
    
    /// `true` if this airport has an on-field navigation facility that is part
    /// of the Minimum Operational Network (MON).
    public let minimumOperationalNetwork: Bool

    // MARK: Inspection Data
    
    /// The method by which this airport was last inspected.
    public let inspectionMethod: InspectionMethod?
    
    /// The agency that performed the last inspection.
    public let inspectionAgency: InspectionAgency?
    
    /// The date the last physical inspection was made.
    public let lastPhysicalInspectionDate: Date?
    
    /// The date the last request for information for this airport was
    /// completed.
    public let lastInformationRequestCompletedDate: Date?

    // MARK: Airport Services
    
    /// A list of fuel types available for purchase.
    public let fuelsAvailable: Array<FuelType>
    
    /// The type of airframe repair available.
    public let airframeRepairAvailable: RepairService?
    
    /// The type of powerplant repair available.
    public let powerplantRepairAvailable: RepairService?
    
    /// The type of bottled oxygen available for purchase.
    public let bottledOxygenAvailable: Array<OxygenPressure>
    
    /// The type of bulk oxygen available for purchase.
    public let bulkOxygenAvailable: Array<OxygenPressure>
    
    /// The type of transient aircraft storage facilities available.
    public let transientStorageFacilities: Array<StorageFacility>?
    
    /// Other services available at this airport.
    public let otherServices: Array<Service>
    
    /// `true` if this airport provides US Government Contract Fuel.
    public let contractFuelAvailable: Bool?

    // MARK: Airport Facilities
    
    /// The schedule for when the airport surface lighting is active.
    public let airportLightingSchedule: LightingSchedule?
    
    /// The schedule for when the rotating beacon is active.
    public let beaconLightingSchedule: LightingSchedule?
    
    /// `true` if this airport has an air traffic control tower.
    public let controlTower: Bool
    
    /// The UNICOM frequency assigned to the airport (in kHz).
    public let UNICOMFrequency: UInt?
    
    /// The common traffic advisory frequency assigned to the airport (in kHz).
    public let CTAF: UInt?
    
    /// Whether this airport has a segmented circle indicating traffic pattern
    /// direction.
    public let segmentedCircle: AirportMarker?
    
    /// The color(s) of the rotating beacon.
    public let beaconColor: LensColor?
    
    /// `true` if this airport has a fee for landing.
    public let landingFee: Bool?
    
    /// `true` if this airport is used by MEDEVAC operators.
    public let medicalUse: Bool?
    
    /// Whether this airport has a windsock or other wind direction indicator.
    public let windIndicator: AirportMarker?

    // MARK: Based Aircraft
    
    /// The number of single-engine general aviation airplanes based at the
    /// airport.
    public let basedSingleEngineGA: UInt?
    
    /// The number of multi-engine general aviation airplanes based at the
    /// airport.
    public let basedMultiEngineGA: UInt?
    
    /// The number of turbine-powered general aviation airplanes based at the
    /// airport.
    public let basedJetGA: UInt?
    
    /// The number of general aviation helicopters based at the airport.
    public let basedHelicopterGA: UInt?
    
    /// The number of operational gliders based at the airport.
    public let basedOperationalGliders: UInt?
    
    /// The number of operating military aircraft based at the airport.
    public let basedOperationalMilitary: UInt?
    
    /// The number of ultralights based at the airport.
    public let basedUltralights: UInt?

    // MARK: Annual Operations
    
    /// The number of part-121 commercial operations per year.
    public let annualCommercialOps: UInt?
    
    /// The number of part-135 commuter operations per year.
    public let annualCommuterOps: UInt?
    
    /// The number of part-135 air taxi operations per year.
    public let annualAirTaxiOps: UInt?
    
    /// The number of part-91 operations by based aircraft per year.
    public let annualLocalGAOps: UInt?
    
    /// The number of part-91 operations by transient aircraft per year.
    public let annualTransientGAOps: UInt?
    
    /// The number of military operations per year.
    public let annualMilitaryOps: UInt?
    
    /// The ending date of the one-year period that the operation statistics
    /// are counted from.
    public let annualPeriodEndDate: Date?
    
    // MARK: Associations
    
    /// The times during which the airport is attended.
    public var attendanceSchedule = Array<AttendanceSchedule>()
    
    /// The runways this airport has.
    public var runways = Array<Runway>()
    
    /// General remarks and per-field remarks.
    public var remarks = Remarks<Field>()
    
    // MARK: - Methods

    init(id: String, name: String, LID: String, ICAOIdentifier: String?, facilityType: Airport.FacilityType, FAARegion: Airport.FAARegion?, FAAFieldOfficeCode: String?, stateCode: String?, county: String, countyStateCode: String, city: String, ownership: Airport.Ownership, publicUse: Bool, owner: Airport.Person?, manager: Airport.Person?, referencePoint: Location, referencePointDeterminationMethod: Airport.LocationDeterminationMethod, elevationDeterminationMethod: Airport.LocationDeterminationMethod?, magneticVariation: Int?, magneticVariationEpoch: Date?, trafficPatternAltitude: Int?, sectionalChart: String?, distanceCityToAirport: UInt?, directionCityToAirport: Direction?, landArea: Float?, boundaryARTCCID: String, responsibleARTCCID: String, tieInFSSOnStation: Bool?, tieInFSSID: String, alternateFSSID: String?, NOTAMIssuerID: String?, NOTAMDAvailable: Bool?, activationDate: Date?, status: Airport.Status, ARFFCapability: Airport.ARFFCapability?, agreements: Array<Airport.FederalAgreement>, airspaceAnalysisDetermination: Airport.AirspaceAnalysisDetermination?, customsEntryAirport: Bool?, customsLandingRightsAirport: Bool?, jointUseAgreement: Bool?, militaryLandingRights: Bool?, inspectionMethod: Airport.InspectionMethod?, inspectionAgency: Airport.InspectionAgency?, lastPhysicalInspectionDate: Date?, lastInformationRequestCompletedDate: Date?, fuelsAvailable: Array<Airport.FuelType>, airframeRepairAvailable: Airport.RepairService?, powerplantRepairAvailable: Airport.RepairService?, bottledOxygenAvailable: Array<Airport.OxygenPressure>, bulkOxygenAvailable: Array<Airport.OxygenPressure>, airportLightingSchedule: Airport.LightingSchedule?, beaconLightingSchedule: Airport.LightingSchedule?, controlTower: Bool, UNICOMFrequency: UInt?, CTAF: UInt?, segmentedCircle: Airport.AirportMarker?, beaconColor: Airport.LensColor?, landingFee: Bool?, medicalUse: Bool?, basedSingleEngineGA: UInt?, basedMultiEngineGA: UInt?, basedJetGA: UInt?, basedHelicopterGA: UInt?, basedOperationalGliders: UInt?, basedOperationalMilitary: UInt?, basedUltralights: UInt?, annualCommercialOps: UInt?, annualCommuterOps: UInt?, annualAirTaxiOps: UInt?, annualLocalGAOps: UInt?, annualTransientGAOps: UInt?, annualMilitaryOps: UInt?, annualPeriodEndDate: Date?, positionSource: String?, positionSourceDate: Date?, elevationSource: String?, elevationSourceDate: Date?, contractFuelAvailable: Bool?, transientStorageFacilities: Array<Airport.StorageFacility>?, otherServices: Array<Airport.Service>, windIndicator: Airport.AirportMarker?, minimumOperationalNetwork: Bool) {
        self.id = id
        self.name = name
        self.LID = LID
        self.ICAOIdentifier = ICAOIdentifier
        self.facilityType = facilityType
        self.FAARegion = FAARegion
        self.FAAFieldOfficeCode = FAAFieldOfficeCode
        self.stateCode = stateCode
        self.county = county
        self.countyStateCode = countyStateCode
        self.city = city
        self.ownership = ownership
        self.publicUse = publicUse
        self.owner = owner
        self.manager = manager
        self.referencePoint = referencePoint
        self.referencePointDeterminationMethod = referencePointDeterminationMethod
        self.elevationDeterminationMethod = elevationDeterminationMethod
        self.magneticVariation = magneticVariation
        self.magneticVariationEpoch = magneticVariationEpoch
        self.trafficPatternAltitude = trafficPatternAltitude
        self.sectionalChart = sectionalChart
        self.distanceCityToAirport = distanceCityToAirport
        self.directionCityToAirport = directionCityToAirport
        self.landArea = landArea
        self.boundaryARTCCID = boundaryARTCCID
        self.responsibleARTCCID = responsibleARTCCID
        self.tieInFSSOnStation = tieInFSSOnStation
        self.tieInFSSID = tieInFSSID
        self.alternateFSSID = alternateFSSID
        self.NOTAMIssuerID = NOTAMIssuerID
        self.NOTAMDAvailable = NOTAMDAvailable
        self.activationDate = activationDate
        self.status = status
        self.ARFFCapability = ARFFCapability
        self.agreements = agreements
        self.airspaceAnalysisDetermination = airspaceAnalysisDetermination
        self.customsEntryAirport = customsEntryAirport
        self.customsLandingRightsAirport = customsLandingRightsAirport
        self.jointUseAgreement = jointUseAgreement
        self.militaryLandingRights = militaryLandingRights
        self.inspectionMethod = inspectionMethod
        self.inspectionAgency = inspectionAgency
        self.lastPhysicalInspectionDate = lastPhysicalInspectionDate
        self.lastInformationRequestCompletedDate = lastInformationRequestCompletedDate
        self.fuelsAvailable = fuelsAvailable
        self.airframeRepairAvailable = airframeRepairAvailable
        self.powerplantRepairAvailable = powerplantRepairAvailable
        self.bottledOxygenAvailable = bottledOxygenAvailable
        self.bulkOxygenAvailable = bulkOxygenAvailable
        self.airportLightingSchedule = airportLightingSchedule
        self.beaconLightingSchedule = beaconLightingSchedule
        self.controlTower = controlTower
        self.UNICOMFrequency = UNICOMFrequency
        self.CTAF = CTAF
        self.segmentedCircle = segmentedCircle
        self.beaconColor = beaconColor
        self.landingFee = landingFee
        self.medicalUse = medicalUse
        self.basedSingleEngineGA = basedSingleEngineGA
        self.basedMultiEngineGA = basedMultiEngineGA
        self.basedJetGA = basedJetGA
        self.basedHelicopterGA = basedHelicopterGA
        self.basedOperationalGliders = basedOperationalGliders
        self.basedOperationalMilitary = basedOperationalMilitary
        self.basedUltralights = basedUltralights
        self.annualCommercialOps = annualCommercialOps
        self.annualCommuterOps = annualCommuterOps
        self.annualAirTaxiOps = annualAirTaxiOps
        self.annualLocalGAOps = annualLocalGAOps
        self.annualTransientGAOps = annualTransientGAOps
        self.annualMilitaryOps = annualMilitaryOps
        self.annualPeriodEndDate = annualPeriodEndDate
        self.positionSource = positionSource
        self.positionSourceDate = positionSourceDate
        self.elevationSource = elevationSource
        self.elevationSourceDate = elevationSourceDate
        self.contractFuelAvailable = contractFuelAvailable
        self.transientStorageFacilities = transientStorageFacilities
        self.otherServices = otherServices
        self.windIndicator = windIndicator
        self.minimumOperationalNetwork = minimumOperationalNetwork
    }

    public static func == (lhs: Airport, rhs: Airport) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Types

    /**
     A person or organization responsible for an airport.
     */
    public struct Person: Codable {
        
        /// The person or organization name.
        public let name: String
        
        /// Line 1 of the mailing address.
        public let address1: String?
        
        /// Line 2 of the mailing address.
        public let address2: String?
        
        /// The contact phone number.
        public let phone: String?
        
        
        /// General or per-field remarks on the person or organization.
        public var remarks = Remarks<Field>()
        
        /// Fields that per-field remarks can be associated with.
        public enum Field: String, Codable {
            case name
            case address1
            case address2
            case phone
            
            static var fieldOrder: Array<Self?> {
                var order = Array<Self?>(repeating: nil, count: 15)
                order.append(contentsOf: [.name, .address1, .address2, .phone,
                                          .name, .address1, .address2, .phone])
                order.append(contentsOf: Array(repeating: nil, count: 82))
                return order
            }
        }
    
        enum CodingKeys: String, CodingKey {
            case name, address1, address2, phone, remarks
        }
    }

    // MARK: - Enums

    /// Types of airports facilities.
    public enum FacilityType: String, Codable, RecordEnum {
        case airport = "AIRPORT"
        case balloonport = "BALLOONPORT"
        case seaport = "SEAPLANE BASE"
        case gliderport = "GLIDERPORT"
        case heliport = "HELIPORT"
        case ultralight = "ULTRALIGHT"
    }

    /// FAA administrative regions.
    public enum FAARegion: String, Codable, RecordEnum {
        case alaska = "AAL"
        case central = "ACE"
        case eastern = "AEA"
        case greatLakes = "AGL"
        case international = "AIN"
        case newEngland = "ANE"
        case northwestMountain = "ANM"
        case southern = "ASO"
        case southwest = "ASW"
        case westernPacific = "AWP"
    }

    /// Airport ownership types.
    public enum Ownership: String, Codable, RecordEnum {
        
        /// Publicly-owned airport.
        case `public` = "PU"
        
        /// Privately-owned airport.
        case `private` = "PR"
        
        /// Owned by the US Air Force.
        case USAF = "MA"
        
        /// Owned by the US Navy.
        case USN = "MN"
        
        /// Owned by the US Army.
        case USArmy = "MR"
        
        /// Owned by the US Coast Guard.
        case USCG = "CG"
    }

    /// Methods for determining an ARP.
    public enum LocationDeterminationMethod: String, Codable, RecordEnum {
        /// ARP was estimated.
        case estimated = "E"
        
        /// ARP was surveyed.
        case surveyed = "S"
    }

    /// Airport availability status.
    public enum Status: String, Codable, RecordEnum {
        
        /// Airport has been closed for an indefinite time.
        case closedIndefinitely = "CI"
        
        /// Airport has been closed permanently.
        case closedPermanently = "CP"
        
        /// Airport is not closed.
        case operational = "O"
    }

    /// Federal agreements that can be in place for an airport.
    public enum FederalAgreement: String, Codable, RecordEnum {
        
        /// National Plan of Integrated Airport Systems
        case NPIAS = "N"
        
        /// Installation of navigational facilities on privately owned airports
        /// under the F&E program
        case FandE = "B"
        
        /// FAAP, ADAP, or IAP grant agreements
        case grantAgreements = "G"
        
        /// Compliance with ADA
        case accessibilityCompliance = "H"
        
        /// Surplus property agreement under Public Law 289
        case surplusPublicLaw289 = "P"
        
        /// Surplus property agreement under Regulation 16-WAA
        case surplusRegulation16WAA = "R"
        
        /// Conveyance under Section 16, Federal Airport Act of 1946; or Section
        /// 23, Airport and Airway Development Act of 1970
        case conveyanceFAA16_23 = "S"
        
        /// Advance planning agreement under FAAP
        case FAAPAdvancePlanning = "V"
        
        /// Obligations assumed by transfer
        case transferObligations = "X"
        
        /// Assurances pursuant to Title VI of the Civil Rights Act of 1964
        case civilRightsActAssurances = "Y"
        
        /// Conveyance under Section 303(c), Federal Aviation Act of 1958
        case conveyanceFAA303C = "Z"
        
        /// Grant agreement has expired; however, agreement remains in effect
        /// for this facility as long as it is public-use
        case expiredGrantAgreement = "1"
        
        /// Section 303(c) authority from FAA Act of 1958 has expired; however,
        /// agreement remains in effect for this facility as long as it is
        /// public-use
        case expired303CAuthority = "2"
        
        /// AP-4 agreement under DLAND or DLCA has expired
        case expiredAP4Agreement = "3"
        
        //TODO: make this an enum with a .other option
        case unknownA = "A"
        case unknownE = "E"
        case unknownL = "L"
        case unknownM = "M"
        case unknownO = "O"
        case unknown0 = "0"
        case unknown4 = "4"
        case unknown5 = "5"
        case unknown6 = "6"
        case unknown7 = "7"
        case unknown8 = "8"
        case unknown9 = "9"
    }

    /// Airspace analysis determinations.
    public enum AirspaceAnalysisDetermination: String, Codable, RecordEnum {
        case conditional = "CONDL"
        case notAnalyzed = "NOT ANALYZED"
        case noObjection = "NO OBJECTION"
        case objectionable = "OBJECTIONABLE"
        
        static var synonyms: Dictionary<String, Self> {[
            "CONDITIONAL": .conditional,
        ]}
    }

    /// Methods for airport inspection.
    public enum InspectionMethod: String, Codable, RecordEnum {
        case federal = "F"
        case state = "S"
        case contractor = "C"
        
        /// 5010-1 Public Use Mailout Program
        case publicUseMailout = "1"
        
        /// 5010-2 Private Use Mailout Program
        case privateUseMailout = "2"
    }

    /// Agency performing physical inspection.
    public enum InspectionAgency: String, Codable, RecordEnum {
        /// FAA airports field personnel
        case FAAPersonnel = "F"
        
        /// State aeronautical personnel
        case statePersonnel = "S"
        
        /// Private contract personnel
        case contractPersonnel = "C"
        
        case owner = "N"
    }

    /// Types of aviation gasoline.
    public enum FuelType: String, Codable, RecordEnum {
        
        /// Grade 80 avgas (red) (ASTM D910)
        case avgas80 = "80"
        
        /// Grade 100 avgas (green) (ASTM D910)
        case avgas100 = "100"
        
        /// Grade 100 avgas, low-lead (blue) (ASTM D910)
        case avgas100LL = "100LL"
        
        /// Grade 115/145 avgas (purple) (MIL-G-5572F)
        case avgas115 = "115"
        
        /// Jet A kerosene, without additives (ASTM D1655)
        case jetA = "A"
        
        /// Jet A+ kerosene, with fuel system icing inhibitor (FSII, aka Prist)
        /// (ASTM D1655)
        case jetAPlus = "A+"
        
        /// Jet A++ kerosene, with FSII, corrosion inhibitor/lubricity improver
        /// (CI/LI), and static dissipator additive (SDA), similar to JP-8
        /// (ASTM D1655)
        case jetAPlusPlus = "A++"
        
        /// Jet A++100 kerosene with FSII, CI/LI, SDA, and +100 thermal
        /// stability improver (ASTM D1655)
        case jetAPlusPlus100 = "A++10"
        
        /// Jet A-1 kerosene (ASTM D1655, DEF STAN 91-91)
        case jetA1 = "A1"
        
        /// Jet A-1 kerosene with FSII (ASTM D1655, DEF STAN 91-91)
        case jetA1Plus = "A1+"
        
        /// Jet B wide-cut fuel, similar to JP-4 (ASTM D6615)
        case jetB = "B"
        
        /// Jet B with FSII (ASTM D6615)
        case jetBPlus = "B+"
        
        /// JP-4 / NATO F-40 wide-cut fuel, with FSII, CI/LI, and SDA
        /// (MIL-DTL-5624)
        case JP4 = "J4"
        
        /// JP-5 / NATO F-44 kerosene, with FSII, CI/LI, SDA, AO, and MDA
        /// (MIL-DTL-5624)
        case JP5 = "J5"
        
        /// JP-8 / NATO F-34 kerosene, with FSII, CI/LI, SDA, possibly
        /// antioxidant (AO) and metal deactivators (MDA) (MIL-DTL-83133, DEF
        /// STAN 91-87)
        case JP8 = "J8"
        
        /// JP-8+100 / NATO F-37 kerosene: JP-8 additized with +100 thermal
        /// stability improver
        case J8Plus100 = "J8+10"
        
        /// Generic jet fuel
        case jetGeneric = "J"
        
        /// Automotive gasoline (ASTM D4814)
        case mogas = "MOGAS"
        
        /// Grade 91 avgas, unleaded (ASTM D7547)
        case avgasUL91 = "UL91"
        
        /// Grade 94 avgas, unleaded (ASTM D7547)
        case avgasUL94 = "UL94"
    }

    /// Repair service levels available.
    public enum RepairService: String, Codable, RecordEnum {
        case major = "MAJOR"
        case minor = "MINOR"
        case none = "NONE"
    }

    /// Oxygen pressure levels available for bulk or bottled purchase.
    public enum OxygenPressure: String, Codable, RecordEnum {
        case high = "HIGH"
        case low = "LOW"
        case none = "NONE"
    }

    /// Types of aircraft storage facilities available.
    public enum StorageFacility: String, Codable, RecordEnum {
        case buoys = "BUOY"
        case hangars = "HANGAR"
        case tiedowns = "TIEDOWN"
        
        static var synonyms: Dictionary<String, Self> {[
            "HGR": .hangars,
            "TIE": .tiedowns
        ]}
    }

    /// Additional services available at an airport.
    public enum Service: String, Codable, RecordEnum {
        case airFreight = "AFRT"
        case cropDusting = "AGRI"
        case airAmbulance = "AMB"
        case avionics = "AVNCS"
        case beachingGear = "BCHGR"
        case cargoHandling = "CARGO"
        case charter = "CHTR"
        case glider = "GLD"
        case pilotInstruction = "INSTR"
        case parachuteJumping = "PAJA"
        case aircraftRental = "RNTL"
        case aircraftSales = "SALES"
        case annualSurveying = "SURV"
        case gliderTowing = "TOW"
    }

    /// Airport surface or beacon lighting schedules.
    public enum LightingSchedule: String, Codable, RecordEnum {
        
        /// From sunset to sunrise=
        case sunsetSunrise = "SS-SR"
        
        /// See remarks for lighting schedule
        case seeRemarks = "SEE RMK"
        
        /// Airport is unlighted
        case unlighted = ""
    }

    /// Types of airport indicators (segmented circle, windsock).
    public enum AirportMarker: String, Codable, RecordEnum {
        
        /// No indication of wind or traffic pattern
        case none = "N"
        
        /// Unlighted windsock or segmented circle
        case unlighted = "Y"
        
        /// Lighted windsock or segmented circle
        case lighted = "Y-L"
    }

    /// Airport rotating beacon colors.
    public enum LensColor: String, Codable, RecordEnum {
        
        /// White-green (lighted public land airport)
        case clearGreen = "CG"
        
        /// White-yellow (lighted public seaport)
        case clearYellow = "CY"
        
        /// White-green-yellow (public heliport)
        case clearGreenYellow = "CGY"
        
        /// white-white-green (lighted military airport)
        case splitClearGreen = "SCG"
        
        /// White (unlighted land airport)
        case clear = "C"
        
        /// Yellow (unlighted seaport)
        case yellow = "Y"
        
        /// Green (lighted land airport)
        case green = "G"
        
        /// No airport beacon
        case none = "N"
    }

    /// Aircraft rescue and firefighting capabilities as defined by FAR 139.
    public struct ARFFCapability: Codable {
        
        /// Airport class
        public let `class`: Class
        
        /// ARFF index
        public let index: Index
        
        /// Type of air service available
        public let airService: AirService
        
        /// ARFF certification date
        public let certificationDate: Date
        
        enum CodingKeys: String, CodingKey {
            case `class`, index, airService, certificationDate
        }

        /// Airport classes as defined by FAR 139.5. For purposes of this enum,
        /// a "large" aircraft has 31 seats or more, and a "small" aircraft has
        /// more than 9 but fewer than 31 seats.
        public enum Class: String, Codable, RecordEnum {
            
            /// Class-I airports serve scheduled and unscheduled operations of
            /// large and small air carrier aircraft.
            case I = "I"
            
            /// Class-II airports serve scheduled operations of small air
            /// carrier aircraft and unscheduled operations of large and small
            /// air carrier aircraft.
            case II = "II"
            
            /// Class-III airports serve scheduled operations of small air
            /// carrier aircraft, and no operations of large air carrier
            /// aircraft.
            case III = "III"
            
            /// Class-IV airports serve unscheduled operations of large air
            /// carrier aircraft, and no operations of small air carrier
            /// aircraft.
            case IV = "IV"
        }

        /// Aircraft indexes are based on the length of the aircraft, defined by
        /// FAR 139.315(b).
        public enum Index: String, Codable, RecordEnum {
            
            /// Aircraft under 90 feet in length
            case A = "A"
            
            /// Aircraft from 90 to but not including 126 feet in length
            case B = "B"
            
            /// Aircraft from 126 to but not including 159 feet in length
            case C = "C"
            
            /// Aircraft from 159 to but not including 200 feet in length
            case D = "D"
            
            /// Aircraft 200 or more feet in length
            case E = "E"
            
            /// Airport has limited ARFF certification under FAR 139.
            case limited = "L"
        }

        /// Type of air service the airport receives.
        public enum AirService: String, Codable, RecordEnum {
            
            /// Airports receiving scheduled air carrier service from carriers
            /// certificated by the Civil Aeronautics Board
            case scheduled = "S"
            
            /// Airports not receiving services indicated by ``scheduled``.
            case unscheduled = "U"
        }
    }
    
    // MARK: - Remarks
    
    /// Fields that per-field remarks can be associated with.
    public enum Field: String, Codable {
        case id, name, LID, ICAOIdentifier, facilityType

        case FAARegion, FAAFieldOfficeCode, stateCode, county, countyStateCode, city

        case ownership, publicUse, owner, manager

        case referencePoint, referencePointDeterminationMethod, elevationDeterminationMethod, magneticVariation, magneticVariationEpoch, trafficPatternAltitude, sectionalChart, distanceCityToAirport, directionCityToAirport, landArea

        case boundaryARTCCID, responsibleARTCCID, tieInFSSOnStation, tieInFSSID, alternateFSSID, NOTAMIssuerID, NOTAMDAvailable

        case activationDate, status, ARFFCapability, agreements, airspaceAnalysisDetermination, customsEntryAirport, customsLandingRightsAirport, jointUseAgreement, militaryLandingRights

        case inspectionMethod, inspectionAgency, lastPhysicalInspectionDate, lastInformationRequestCompletedDate

        case fuelsAvailable, airframeRepairAvailable, powerplantRepairAvailable, bottledOxygenAvailable, bulkOxygenAvailable

        case airportLightingSchedule, beaconLightingSchedule, controlTower, UNICOMFrequency, CTAF, segmentedCircle, beaconColor, landingFee, medicalUse

        case basedSingleEngineGA, basedMultiEngineGA, basedJetGA, basedHelicopterGA, basedOperationalGliders, basedOperationalMilitary, basedUltralights

        case annualCommercialOps, annualCommuterOps, annualAirTaxiOps, annualLocalGAOps, annualTransientGAOps, annualMilitaryOps, annualPeriodEndDate

        case positionSource, positionSourceDate, elevationSource, elevationSourceDate, contractFuelAvailable, transientStorageFacilities, otherServices, windIndicator, minimumOperationalNetwork
        
        case attendanceSchedule
        
        static let fieldOrder: Array<Self?> = [
            nil, .id, .facilityType, .LID, nil,
            .FAARegion, .FAAFieldOfficeCode, .stateCode, .stateCode, .county, .countyStateCode, .city, .name,
            .ownership, .publicUse, .owner, .owner, .owner, .owner, .manager, .manager, .manager, .manager,
            .referencePoint, .referencePoint, .referencePoint, .referencePoint, .referencePointDeterminationMethod, .referencePoint, .elevationDeterminationMethod, .magneticVariation, .magneticVariationEpoch, .trafficPatternAltitude, .sectionalChart, .distanceCityToAirport, .directionCityToAirport, .landArea,
            .boundaryARTCCID, .boundaryARTCCID, .boundaryARTCCID, .responsibleARTCCID, .responsibleARTCCID, .responsibleARTCCID, .tieInFSSOnStation, .tieInFSSID, .tieInFSSID, .tieInFSSID, .tieInFSSID, .alternateFSSID, .alternateFSSID, .alternateFSSID, .NOTAMIssuerID, .NOTAMDAvailable,
            activationDate, .status, .ARFFCapability, .agreements, .airspaceAnalysisDetermination, .customsEntryAirport, .customsLandingRightsAirport, .jointUseAgreement, .militaryLandingRights,
            .inspectionMethod, .inspectionAgency, .lastPhysicalInspectionDate, .lastInformationRequestCompletedDate,
            .fuelsAvailable, .airframeRepairAvailable, .powerplantRepairAvailable, .bottledOxygenAvailable, .bulkOxygenAvailable,
            .airportLightingSchedule, .beaconLightingSchedule, .controlTower, .UNICOMFrequency, .CTAF, .segmentedCircle, .beaconColor, .landingFee, .medicalUse,
            .basedSingleEngineGA, .basedMultiEngineGA, .basedJetGA, .basedHelicopterGA, .basedOperationalGliders, .basedOperationalMilitary, .basedUltralights,
            .annualCommercialOps, .annualCommuterOps, .annualAirTaxiOps, .annualLocalGAOps, .annualTransientGAOps, .annualMilitaryOps, .annualPeriodEndDate,
            .positionSource, .positionSourceDate, .elevationSource, .elevationSourceDate, .contractFuelAvailable, .transientStorageFacilities, .otherServices, .windIndicator, .ICAOIdentifier, .minimumOperationalNetwork, nil
        ]
    }
    
    // MARK: - Coding
    
    public enum CodingKeys: String, CodingKey {
      case id, name, LID, ICAOIdentifier, facilityType, FAARegion, FAAFieldOfficeCode, stateCode, county, countyStateCode, city, ownership, publicUse, owner, manager, referencePoint, referencePointDeterminationMethod, elevationDeterminationMethod, magneticVariation, magneticVariationEpoch, trafficPatternAltitude, sectionalChart, distanceCityToAirport, directionCityToAirport, landArea, boundaryARTCCID, responsibleARTCCID, tieInFSSOnStation, tieInFSSID, alternateFSSID, NOTAMIssuerID, NOTAMDAvailable, activationDate, status, ARFFCapability, agreements, airspaceAnalysisDetermination, customsEntryAirport, customsLandingRightsAirport, jointUseAgreement, militaryLandingRights, inspectionMethod, inspectionAgency, lastPhysicalInspectionDate, lastInformationRequestCompletedDate, fuelsAvailable, airframeRepairAvailable, powerplantRepairAvailable, bottledOxygenAvailable, bulkOxygenAvailable, airportLightingSchedule, beaconLightingSchedule, controlTower, UNICOMFrequency, CTAF, segmentedCircle, beaconColor, landingFee, medicalUse, basedSingleEngineGA, basedMultiEngineGA, basedJetGA, basedHelicopterGA, basedOperationalGliders, basedOperationalMilitary, basedUltralights, annualCommercialOps, annualCommuterOps, annualAirTaxiOps, annualLocalGAOps, annualTransientGAOps, annualMilitaryOps, annualPeriodEndDate, positionSource, positionSourceDate, elevationSource, elevationSourceDate, contractFuelAvailable, transientStorageFacilities, otherServices, windIndicator, minimumOperationalNetwork
      
      case attendanceSchedule, runways, remarks
    }
}

