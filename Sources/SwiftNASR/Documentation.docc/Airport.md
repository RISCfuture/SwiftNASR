# ``SwiftNASR/Airport``

@Metadata {
    @DocumentationExtension(mergeBehavior: append)
}

## Topics

### Associations

- ``runways``
- ``remarks``
- ``attendanceSchedule``

### Properties

- ``name``
- ``LID``
- ``ICAOIdentifier``
- ``facilityType-swift.property``

### Demographics

- ``FAARegion-swift.property``
- ``FAAFieldOfficeCode``
- ``stateCode``
- ``state``
- ``county``
- ``countyStateCode``
- ``countyState``
- ``city``

### Ownership

- ``ownership-swift.property``
- ``publicUse``
- ``owner``
- ``manager``

### Geographics

- ``referencePoint``
- ``referencePointDeterminationMethod``
- ``elevationDeterminationMethod``
- ``magneticVariation``
- ``magneticVariationEpoch``
- ``trafficPatternAltitude``
- ``sectionalChart``
- ``distanceCityToAirport``
- ``directionCityToAirport``
- ``landArea``
- ``positionSource``
- ``positionSourceDate``
- ``elevationSource``
- ``elevationSourceDate``

### FAA Services

- ``boundaryARTCCID``
- ``boundaryARTCCs``
- ``responsibleARTCCID``
- ``responsibleARTCCs``
- ``tieInFSSID``
- ``tieInFSS``
- ``tieInFSSOnStation``
- ``alternateFSSID``
- ``alternateFSS``
- ``NOTAMIssuerID``
- ``NOTAMIssuer``
- ``NOTAMDAvailable``

### Federal Status

- ``activationDate``
- ``status-swift.property``
- ``ARFFCapability-swift.property``
- ``agreements``
- ``airspaceAnalysisDetermination-swift.property``
- ``customsEntryAirport``
- ``customsLandingRightsAirport``
- ``jointUseAgreement``
- ``militaryLandingRights``
- ``minimumOperationalNetwork``

### Inspection Data

- ``inspectionMethod-swift.property``
- ``inspectionAgency-swift.property``
- ``lastPhysicalInspectionDate``
- ``lastInformationRequestCompletedDate``

### Airport Services

- ``fuelsAvailable``
- ``airframeRepairAvailable``
- ``powerplantRepairAvailable``
- ``bottledOxygenAvailable``
- ``bulkOxygenAvailable``
- ``transientStorageFacilities``
- ``otherServices``
- ``contractFuelAvailable``

### Airport Facilities

- ``airportLightingSchedule``
- ``beaconLightingSchedule``
- ``controlTower``
- ``UNICOMFrequency``
- ``CTAF``
- ``segmentedCircle``
- ``beaconColor``
- ``landingFee``
- ``medicalUse``
- ``windIndicator``

### Based Aircraft

- ``basedSingleEngineGA``
- ``basedMultiEngineGA``
- ``basedJetGA``
- ``basedHelicopterGA``
- ``basedOperationalGliders``
- ``basedOperationalMilitary``
- ``basedUltralights``

### Annual Operations

- ``annualCommercialOps``
- ``annualCommuterOps``
- ``annualAirTaxiOps``
- ``annualLocalGAOps``
- ``annualTransientGAOps``
- ``annualMilitaryOps``
- ``annualPeriodEndDate``

### Associated Record Classes

- ``Runway``
- ``AttendanceSchedule``
- ``Remark``

### Associated Types

- ``Person``
- ``FacilityType-swift.enum``
- ``FAARegion-swift.enum``
- ``Ownership-swift.enum``
- ``LocationDeterminationMethod``
- ``Status-swift.enum``
- ``FederalAgreement``
- ``AirspaceAnalysisDetermination-swift.enum``
- ``InspectionMethod-swift.enum``
- ``InspectionAgency-swift.enum``
- ``FuelType``
- ``RepairService``
- ``OxygenPressure``
- ``StorageFacility``
- ``Service``
- ``LightingSchedule``
- ``AirportMarker``
- ``LensColor``
- ``ARFFCapability-swift.struct``
