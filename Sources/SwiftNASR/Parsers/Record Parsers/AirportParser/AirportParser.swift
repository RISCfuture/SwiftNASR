import Foundation

enum AirportRecordIdentifier: String {
    case airport = "APT"
    case attendanceSchedule = "ATT"
    case runway = "RWY"
    case runwayArrestingSystem = "ARS"
    case remark = "RMK"
}

class AirportParser: FixedWidthParser {
    typealias RecordIdentifier = AirportRecordIdentifier

    static let type: RecordType = .airports
    static let layoutFormatOrder: [RecordIdentifier] = [.airport, .attendanceSchedule, .runway, .runwayArrestingSystem, .remark]
    var formats = [NASRTable]()

    var airports = [String: Airport]()

    // MARK: - Transformers

    private let airportTransformer = FixedWidthTransformer([
        .recordType,                                                            //   0 record type
        .string(),                                                              //   1 site number
        .generic { try raw($0, toEnum: Airport.FacilityType.self) },            //   2 facility type
        .string(),                                                              //   3 LID
        .null,                                                                  //   4 effective date

        .generic({ try raw($0, toEnum: Airport.FAARegion.self) },
                 nullable: .blank),                                             //   5 region code
        .string(nullable: .sentinel(["NONE"])),                                 //   6 field office code
        .string(nullable: .blank),                                              //   7 state post office code
        .null,                                                                  //   8 state name
        .string(),                                                              //   9 county name
        .string(),                                                              //  10 county state post office code
        .string(),                                                              //  11 city
        .string(),                                                              //  12 airport name

        .generic { try raw($0, toEnum: Airport.Ownership.self) },               //  13 ownership type
        .boolean(trueValue: "PU"),                                              //  14 facility use
        .string(nullable: .blank),                                              //  15 owner's name
        .string(nullable: .blank),                                              //  16 owner's address
        .string(nullable: .blank),                                              //  17 owner's city state zip
        .string(nullable: .blank),                                              //  18 owner's phone
        .string(nullable: .blank),                                              //  19 manager's name
        .string(nullable: .blank),                                              //  20 manager's address
        .string(nullable: .blank),                                              //  21 manager's city state zip
        .string(nullable: .blank),                                              //  22 manager's phone

        .DDMMSS(),                                                              //  23 lat - formatted
        .null,                                                                  //  24 lat - decimal
        .DDMMSS(),                                                              //  25 lon - formatted
        .null,                                                                  //  26 lon - decimal
        .generic { try raw($0, toEnum: Airport.LocationDeterminationMethod.self) }, // 27 ARP determination method
        .float(),                                                               //  28 elevation
        .generic({ try raw($0, toEnum: Airport.LocationDeterminationMethod.self) },
                 nullable: .blank),                                             //  29 elevation determination method
        .generic({ try parseMagVar($0, fieldIndex: 30) }, nullable: .blank),    //  30 magvar
        .datetime(formatter: FixedWidthTransformer.yearOnly, nullable: .blank), //  31 magvar epoch
        .integer(nullable: .blank),                                             //  32 TPA
        .string(nullable: .blank),                                              //  33 sectional
        .unsignedInteger(nullable: .blank),                                     //  34 distance to city
        .generic({ return try raw($0, toEnum: Direction.self) },
                 nullable: .blank),                                             //  35 direction city -> airport
        .float(nullable: .blank),                                               //  36 land area

        .string(),                                                              //  37 ARTCC ID
        .null,                                                                  //  38 ARTCC computer ID
        .null,                                                                  //  39 ARTCC name
        .string(),                                                              //  40 responsible ARTCC ID
        .null,                                                                  //  41 responsible ARTCC computer ID
        .null,                                                                  //  42 responsible ARTCC name
        .boolean(nullable: .blank),                                             //  43 tie-in FSS on field
        .string(),                                                              //  44 tie-in FSS ID
        .string(),                                                              //  45 tie-in FSS name
        .null,                                                                  //  46 local FSS number
        .null,                                                                  //  47 toll-free FSS number
        .string(nullable: .blank),                                              //  48 alternate FSS ID
        .null,                                                                  //  49 alternate FSS name
        .null,                                                                  //  60 alternate FSS toll-free number
        .string(nullable: .blank),                                              //  51 NOTAM faclity ID
        .boolean(nullable: .blank),                                             //  52 NOTAM D available

        .datetime(formatter: FixedWidthTransformer.monthYear, nullable: .blank),//  53 activation date
        .generic { Airport.Status(rawValue: $0) },                             //  54 status code
        .delimitedArray(delimiter: " ",
                        convert: { $0 },
                        nullable: .compact,
                        emptyPlaceholders: ["BLANK"]),                          //  55 ARFF certification type and date
        .fixedWidthArray(convert: { try raw($0, toEnum: Airport.FederalAgreement.self) },
                         nullable: .compact,
                         emptyPlaceholders: ["NONE", "BLANK"]),                 //  56 federal agreements code
        .generic({ try raw($0, toEnum: Airport.AirspaceAnalysisDetermination.self) },
                 nullable: .blank),                                             //  57 airspace analysis determination
        .boolean(nullable: .blank),                                             //  58 airport of entry
        .boolean(nullable: .blank),                                             //  59 customs airport
        .boolean(nullable: .blank),                                             //  60 joint use
        .boolean(nullable: .blank),                                             //  61 military landing rights

        .generic({ try raw($0, toEnum: Airport.InspectionMethod.self) },
                 nullable: .blank),                                             //  62 inspection method
        .generic({ try raw($0, toEnum: Airport.InspectionAgency.self) },
                 nullable: .blank),                                             //  63 inspection agency
        .datetime(formatter: FixedWidthTransformer.monthDayYear,
                  nullable: .blank),                                            //  64 last inspection date
        .datetime(formatter: FixedWidthTransformer.monthDayYear,
                  nullable: .blank),                                            //  65 last information request completed date

        .fixedWidthArray(width: 5,
                         convert: { Airport.FuelType(rawValue: $0) },
                         nullable: .compact),                                   //  66 available fuel types
        .generic({ try raw($0, toEnum: Airport.RepairService.self) },
                 nullable: .blank),                                             //  67 airframe repair available
        .generic({ try raw($0, toEnum: Airport.RepairService.self) },
                 nullable: .blank),                                             //  68 powerplant repair available
        .delimitedArray(delimiter: "/",
                        convert: { try raw($0, toEnum: Airport.OxygenPressure.self) },
                        nullable: .compact,
                        emptyPlaceholders: ["NONE"]),                           //  69 bottled oxygen available
        .delimitedArray(delimiter: "/",
                        convert: { try raw($0, toEnum: Airport.OxygenPressure.self) },
                        nullable: .compact,
                        emptyPlaceholders: ["NONE"]),                           //  70 bulk oxygen available

        .generic({ try raw($0, toEnum: Airport.LightingSchedule.self) },
                 nullable: .blank),                                             //  71 airport lighting schedule
        .generic({ try raw($0, toEnum: Airport.LightingSchedule.self) },
                 nullable: .blank),                                             //  72 beacon lighting schedule
        .boolean(),                                                             //  73 has control tower
        .frequency(nullable: .blank),                                           //  74 UNICOM
        .frequency(nullable: .blank),                                           //  75 CTAF
        .generic({ segCir in
            segCir == "NONE" ?
            Airport.AirportMarker.none :
            try raw(segCir, toEnum: Airport.AirportMarker.self) },
                 nullable: .blank),                                             //  76 segmented circle
        .generic({ try raw($0, toEnum: Airport.LensColor.self) },
                 nullable: .blank),                                             //  77 beacon color
        .boolean(nullable: .blank),                                             //  78 landing fee
        .boolean(nullable: .blank),                                             //  79 medical use

        .unsignedInteger(nullable: .blank),                                     //  80 GA singles
        .unsignedInteger(nullable: .blank),                                     //  81 GA twins
        .unsignedInteger(nullable: .blank),                                     //  82 GA jets
        .unsignedInteger(nullable: .blank),                                     //  83 GA helis
        .unsignedInteger(nullable: .blank),                                     //  84 gliders
        .unsignedInteger(nullable: .blank),                                     //  85 military aircraft
        .unsignedInteger(nullable: .blank),                                     //  86 ultralights

        .unsignedInteger(nullable: .blank),                                     //  87 commercial ops
        .unsignedInteger(nullable: .blank),                                     //  88 commuter ops
        .unsignedInteger(nullable: .blank),                                     //  89 air taxi ops
        .unsignedInteger(nullable: .blank),                                     //  90 GA local ops
        .unsignedInteger(nullable: .blank),                                     //  91 GA transient ops
        .unsignedInteger(nullable: .blank),                                     //  92 military ops
        .datetime(formatter: FixedWidthTransformer.monthDayYearSlash,
                  nullable: .blank),                                            //  93 ops 12-month period end date

        .string(nullable: .blank),                                              //  94 position source
        .datetime(formatter: FixedWidthTransformer.monthDayYearSlash,
                  nullable: .blank),                                            //  95 position source date
        .string(nullable: .blank),                                              //  96 elevation source
        .datetime(formatter: FixedWidthTransformer.monthDayYearSlash,
                  nullable: .blank),                                            //  97 elevation source date
        .boolean(nullable: .blank),                                             //  98 contract fuel available
        .delimitedArray(delimiter: ",",
                        convert: { try raw($0, toEnum: Airport.StorageFacility.self) },
                        nullable: .compact),                                    // 99 transient storage facilities
        .delimitedArray(delimiter: ",",
                        convert: { try raw($0, toEnum: Airport.Service.self) },
                        nullable: .compact),                                    // 100 other services
        .generic({ try raw($0, toEnum: Airport.AirportMarker.self) },
                 nullable: .blank),                                             // 101 wind indicator
        .string(nullable: .blank),                                              // 102 ICAO code
        .boolean(),                                                             // 103 MON
        .null                                                                   // 104 blank
    ])

    // MARK: - Parsers

    func parseValues(_ values: [String], for identifier: AirportRecordIdentifier) throws {
        switch identifier {
        case .airport:
            try parseAirportRecord(values)
        case .attendanceSchedule:
            try parseAttendanceRecord(values)
        case .remark:
            try parseRemarkRecord(values)
        case .runway:
            try parseRunwayRecord(values)
        case .runwayArrestingSystem:
            try parseArrestingSystemRecord(values)
        }
    }

    private func parseAirportRecord(_ values: [String]) throws {
        let transformedValues = try airportTransformer.applyTo(values)

        let owner = parsePerson(values: transformedValues[15...18])
        let manager = parsePerson(values: transformedValues[19...22])

        let ARFFCapability = try (transformedValues[55] as! [String]).presence.map { ARFFString in
            guard let ARFFClass = Airport.ARFFCapability.Class(rawValue: ARFFString[0]) else {
                throw FixedWidthParserError.invalidValue(ARFFString[0], at: 55)
            }
            guard let ARFFIndex = Airport.ARFFCapability.Index(rawValue: ARFFString[1]) else {
                throw FixedWidthParserError.invalidValue(ARFFString[1], at: 55)
            }
            guard let ARFFService = Airport.ARFFCapability.AirService(rawValue: ARFFString[2]) else {
                throw FixedWidthParserError.invalidValue(ARFFString[2], at: 55)
            }
            guard let ARFFDate = FixedWidthTransformer.monthYear.date(from: ARFFString[3]) else {
                throw FixedWidthParserError.invalidValue(ARFFString[3], at: 55)
            }
            return Airport.ARFFCapability(
                class: ARFFClass,
                index: ARFFIndex,
                airService: ARFFService,
                certificationDate: ARFFDate)
        }

        let location = Location(latitude: transformedValues[23] as! Float,
                                longitude: transformedValues[25] as! Float,
                                elevation: (transformedValues[28] as! Float))

        let airport = Airport(id: transformedValues[1] as! String,
                              name: transformedValues[12] as! String,
                              LID: transformedValues[3] as! String,
                              ICAOIdentifier: transformedValues[102] as! String?,
                              facilityType: transformedValues[2] as! Airport.FacilityType,
                              FAARegion: transformedValues[5] as! Airport.FAARegion?,
                              FAAFieldOfficeCode: transformedValues[6] as! String?,
                              stateCode: transformedValues[7] as! String?,
                              county: transformedValues[9] as! String,
                              countyStateCode: transformedValues[10] as! String,
                              city: transformedValues[11] as! String,
                              ownership: transformedValues[13] as! Airport.Ownership,
                              publicUse: transformedValues[14] as! Bool,
                              owner: owner,
                              manager: manager,
                              referencePoint: location,
                              referencePointDeterminationMethod: transformedValues[27] as! Airport.LocationDeterminationMethod,
                              elevationDeterminationMethod: transformedValues[29] as! Airport.LocationDeterminationMethod?,
                              magneticVariation: transformedValues[30] as! Int?,
                              magneticVariationEpoch: transformedValues[31] as! Date?,
                              trafficPatternAltitude: transformedValues[32] as! Int?,
                              sectionalChart: transformedValues[33] as! String?,
                              distanceCityToAirport: transformedValues[34] as! UInt?,
                              directionCityToAirport: transformedValues[35] as! Direction?,
                              landArea: transformedValues[36] as! Float?,
                              boundaryARTCCID: transformedValues[37] as! String,
                              responsibleARTCCID: transformedValues[40] as! String,
                              tieInFSSOnStation: transformedValues[43] as! Bool?,
                              tieInFSSID: transformedValues[44] as! String,
                              alternateFSSID: transformedValues[48] as! String?,
                              NOTAMIssuerID: transformedValues[51] as! String?,
                              NOTAMDAvailable: transformedValues[52] as! Bool?,
                              activationDate: transformedValues[53] as! Date?,
                              status: transformedValues[54] as! Airport.Status,
                              ARFFCapability: ARFFCapability,
                              agreements: transformedValues[56] as! [Airport.FederalAgreement],
                              airspaceAnalysisDetermination: transformedValues[57] as! Airport.AirspaceAnalysisDetermination?,
                              customsEntryAirport: transformedValues[58] as! Bool?,
                              customsLandingRightsAirport: transformedValues[59] as! Bool?,
                              jointUseAgreement: transformedValues[60] as! Bool?,
                              militaryLandingRights: transformedValues[61] as! Bool?,
                              inspectionMethod: transformedValues[62] as! Airport.InspectionMethod?,
                              inspectionAgency: transformedValues[63] as! Airport.InspectionAgency?,
                              lastPhysicalInspectionDate: transformedValues[64] as! Date?,
                              lastInformationRequestCompletedDate: transformedValues[65] as! Date?,
                              fuelsAvailable: transformedValues[66] as! [Airport.FuelType],
                              airframeRepairAvailable: transformedValues[67] as! Airport.RepairService?,
                              powerplantRepairAvailable: transformedValues[68] as! Airport.RepairService?,
                              bottledOxygenAvailable: transformedValues[69] as! [Airport.OxygenPressure],
                              bulkOxygenAvailable: transformedValues[70] as! [Airport.OxygenPressure],
                              airportLightingSchedule: transformedValues[71] as! Airport.LightingSchedule?,
                              beaconLightingSchedule: transformedValues[72] as! Airport.LightingSchedule?,
                              controlTower: transformedValues[73] as! Bool,
                              UNICOMFrequency: transformedValues[74] as! UInt?,
                              CTAF: transformedValues[75] as! UInt?,
                              segmentedCircle: transformedValues[76] as! Airport.AirportMarker?,
                              beaconColor: transformedValues[77] as! Airport.LensColor?,
                              landingFee: transformedValues[78] as! Bool?,
                              medicalUse: transformedValues[79] as! Bool?,
                              basedSingleEngineGA: transformedValues[80] as! UInt?,
                              basedMultiEngineGA: transformedValues[81] as! UInt?,
                              basedJetGA: transformedValues[82] as! UInt?,
                              basedHelicopterGA: transformedValues[83] as! UInt?,
                              basedOperationalGliders: transformedValues[84] as! UInt?,
                              basedOperationalMilitary: transformedValues[85] as! UInt?,
                              basedUltralights: transformedValues[86] as! UInt?,
                              annualCommercialOps: transformedValues[87] as! UInt?,
                              annualCommuterOps: transformedValues[88] as! UInt?,
                              annualAirTaxiOps: transformedValues[89] as! UInt?,
                              annualLocalGAOps: transformedValues[90] as! UInt?,
                              annualTransientGAOps: transformedValues[91] as! UInt?,
                              annualMilitaryOps: transformedValues[92] as! UInt?,
                              annualPeriodEndDate: transformedValues[93] as! Date?,
                              positionSource: transformedValues[94] as! String?,
                              positionSourceDate: transformedValues[95] as! Date?,
                              elevationSource: transformedValues[96] as! String?,
                              elevationSourceDate: transformedValues[97] as! Date?,
                              contractFuelAvailable: transformedValues[98] as! Bool?,
                              transientStorageFacilities: transformedValues[99] as! [Airport.StorageFacility]?,
                              otherServices: transformedValues[100] as! [Airport.Service],
                              windIndicator: transformedValues[101] as! Airport.AirportMarker?,
                              minimumOperationalNetwork: transformedValues[103] as! Bool)

        airports[airport.id] = airport
    }

    func finish(data: NASRData) async {
        await data.finishParsing(airports: Array(airports.values))
    }

    // MARK: - Support Methods

    private func parsePerson(values: ArraySlice<Any?>) -> Airport.Person? {
        guard let name = values[values.startIndex] as? String else {
            return nil
        }
        let address1 = values[values.index(values.startIndex, offsetBy: 1)] as? String
        let address2 = values[values.index(values.startIndex, offsetBy: 2)] as? String

        var phone = values[values.index(values.startIndex, offsetBy: 3)] as? String
        if phone != nil {
            if phone!.starts(with: "1-") { phone = "1-800-\(phone![phone!.index(phone!.startIndex, offsetBy: 2)...])" }
            else if phone!.starts(with: "8-") { phone = "800-\(phone![phone!.index(phone!.startIndex, offsetBy: 2)...])" }
        }

        return Airport.Person(name: name,
                              address1: address1,
                              address2: address2,
                              phone: phone)
    }
}
