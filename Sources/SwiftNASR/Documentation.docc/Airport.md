# ``SwiftNASR/Airport``

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

- ``faaRegion``
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
- ``magneticVariationDeg``
- ``magneticVariationEpoch``
- ``trafficPatternAltitudeFtAGL``
- ``sectionalChart``
- ``distanceCityToAirportNM``
- ``directionCityToAirport``
- ``landAreaAcres``
- ``positionSource``
- ``positionSourceDate``
- ``elevationSource``
- ``elevationSourceDate``

### FAA Services

- ``boundaryARTCCId``
- ``boundaryARTCCs``
- ``responsibleARTCCId``
- ``responsibleARTCCs``
- ``tieInFSSId``
- ``tieInFSS``
- ``tieInFSSOnStation``
- ``alternateFSSId``
- ``alternateFSS``
- ``NOTAMIssuerId``
- ``NOTAMIssuer``
- ``NOTAMDAvailable``

### Federal Status

- ``activationDate``
- ``status-swift.property``
- ``ARFFCapability-swift.struct``
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
- ``UNICOMFrequencyKHz``
- ``CTAFKHz``
- ``segmentedCircle``
- ``beaconColor``
- ``hasLandingFee``
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
- ``SurveyMethod``
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
- ``AirportMarker``
- ``LensColor``
- ``ARFFCapability-swift.struct``
