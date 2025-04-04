/**
 An air route traffic control center ("Center") is a facility that provides
 separate services to enroute air traffic. Each center facility controls traffic
 within its flight information region (FIR) or upper information region (UIR).
 Centers are split by the FIR they control, their location name, and the site
 type. There is one entry for each combination of those three fields.
 */

public struct ARTCC: ParentRecord {

    // MARK: - Properties

    /// The computer ID for the FIR, e.g. "ZOA" for Oakland Center.
    public let ID: String

    /// The ICAO ID for the FIR, e.g. "KZOA" for Oakland Center.
    public let ICAOID: String?

    /// The facility type.
    public let type: FacilityType

    /// The center name, e.g. "OAKLAND" for Oakland Center.
    public let name: String

    /// An alternate name for the Center.
    public let alternateName: String?

    /// The location of the Center facility.
    public let locationName: String

    /// The state post office code containing the Center facility.
    public let stateCode: String?

    /// The exact location of the controlling facility.
    public let location: Location?

    /// General and per-field remarks.
    public var remarks = Remarks<Field>()

    /// The frequencies this Center communicates on.
    public var frequencies: [CommFrequency] = []

    public var id: String { "\(self.ID).\(type).\(locationName)" }

    weak var data: NASRData?

    // MARK: - Methods

    init(ID: String,
         ICAOID: String?,
         type: Self.FacilityType,
         name: String,
         alternateName: String?,
         locationName: String,
         stateCode: String?,
         location: Location?) {
        self.ID = ID
        self.ICAOID = ICAOID
        self.type = type
        self.name = name
        self.alternateName = alternateName
        self.locationName = locationName
        self.stateCode = stateCode
        self.location = location
    }

    // MARK: - Enums

    enum CodingKeys: String, CodingKey {
        case ID, ICAOID, type, name, alternateName, locationName, stateCode, location, remarks, frequencies
    }

    /// ARTCC facility types.
    public enum FacilityType: String, RecordEnum {

        /// Air route surveillance radar
        case ARSR

        /// Air traffic center control center
        case ARTCC

        /// Center radar approach control facility
        case CERAP

        /// Remote communications, air-to-ground
        case RCAG

        /// Secondary radar
        case SECRA
    }

    /// Fields that per-field remarks can be associated with.
    public enum Field: String, RemarkField {
        case alternateName, stateCode, location

        static let fieldOrder: [Self?] = [
            nil, nil, nil, nil, .alternateName, nil, nil, .stateCode,
            .stateCode, .location, .location, .location, .location, nil, nil
        ]
    }

    // MARK: - Classes

    /// A radio frequency that a Center controller communicates over.
    public struct CommFrequency: Record {

        /// The radio frequency, in kHz.
        public let frequency: UInt

        /// The altitude blocks that this frequency is used for.
        public let altitude: [Altitude]

        /// Special usage name (e.g., "approach control", "discrete",
        /// "do not publish").
        public let specialUsageName: String?

        /// `true` if the RCAG frequency is charted.
        public let remoteOutletFrequencyCharted: Bool?

        /// FAA location identifier (not site number) of the associated airport,
        /// if this facility is associated with an airport.
        public var associatedAirportCode: String?

        /// General and per-field remarks.
        public var remarks = Remarks<Field>()

        // used to cross-reference airport from airport code
        var findAirportByID: (@Sendable (_ airportID: String) async -> Airport?)!

        /// Fields that per-field remarks can be associated with.
        public enum Field: String, RemarkField {
            case altitude, specialUsageName, associatedAirportCode

            static let fieldOrder: [Self?] = [
                nil, nil, nil, nil, nil, .altitude, .specialUsageName, nil,
                .associatedAirportCode, .associatedAirportCode,
                .associatedAirportCode, .associatedAirportCode,
                .associatedAirportCode, .associatedAirportCode,
                .associatedAirportCode, .associatedAirportCode,
                .associatedAirportCode
            ]
        }

        enum CodingKeys: String, CodingKey {
            case frequency, altitude, specialUsageName, remoteOutletFrequencyCharted, associatedAirportCode, remarks
        }

        init(frequency: UInt,
             altitude: [Altitude],
             specialUsageName: String?,
             remoteOutletFrequencyCharted: Bool?,
             associatedAirportCode: String?) {
            self.frequency = frequency
            self.altitude = altitude
            self.specialUsageName = specialUsageName
            self.remoteOutletFrequencyCharted = remoteOutletFrequencyCharted
            self.associatedAirportCode = associatedAirportCode
        }

        /// Altitude blocks that a frequency is used to control traffic within.
        public enum Altitude: String, RecordEnum {

            /// Flight levels 230 and below
            case low = "LOW"

            /// Flight levels 240 to (but not including) 330
            case high = "HIGH"

            /// Flight levels 330 and above
            case ultraHigh = "ULTRA-HIGH"
        }
    }
}
