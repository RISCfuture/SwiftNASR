import Foundation

/**
 A data class containing all data parsed from a NASR distribution. The
 members of this class will be `nil` until their respective calls to
 ``NASR/parse(_:withProgress:errorHandler:)`` have been made.

 This class can be encoded to disk using ``NASRDataCodable``, and re-associated
 with a SwiftNASR object using ``NASR/fromData(_:)``. Parsing the data takes
 much longer than decoding it, so it is recommended to parse the data only once
 per cycle, and retrieve it using a `Decoder` thereafter.

 To encode a `NASRData` instance, create a new `NASRDataCodable` instance using
 ``NASRDataCodable/init(data:)``, and then encode it using your `Encoder` of
 choice. To decode your data, use ``NASRDataCodable/init(from:)``, and then
 convert it to a `NASRData` instance using ``NASRDataCodable/makeData()``.

 NASRData is also responsible for providing cross-references between classes.
 For example, the ``FSS/airport`` property references an ``Airport``
 which is part of the same containing ``NASRData`` instance. Rather than
 directly set a reference between the FSS and the airport (which can create
 circular dependencies), ``FSS/airport`` is a computed property that uses the
 containing ``NASRData`` instance to find the associated airport.
 */

public actor NASRData {

  /// The cycle for the NASR distribution containing this data.
  public var cycle: Cycle?

  /// US states and territories.
  public var states: [State]?

  /// Airports loaded by SwiftNASR.
  public var airports: [Airport]? {
    didSet {
      guard airports != nil else { return }
      for airportID in 0..<airports!.count {
        airports![airportID].data = self
        let findRunwayById = airports![airportID].findRunwayById()
        for runwayIndex in 0..<airports![airportID].runways.count {
          airports![airportID].runways[runwayIndex].baseEnd.LAHSO?.findRunwayById = findRunwayById
          airports![airportID].runways[runwayIndex].reciprocalEnd?.LAHSO?.findRunwayById =
            findRunwayById
        }
      }
    }
  }

  /// ARTCCs loaded by SwiftNASR.
  public var ARTCCs: [ARTCC]? {
    didSet {
      guard ARTCCs != nil else { return }
      for ARTCCIndex in 0..<ARTCCs!.count {
        ARTCCs![ARTCCIndex].data = self
        let findRunwayById = ARTCCs![ARTCCIndex].findAirportById()
        for freqIndex in 0..<ARTCCs![ARTCCIndex].frequencies.count {
          ARTCCs![ARTCCIndex].frequencies[freqIndex].findAirportById = findRunwayById
        }
      }
    }
  }

  /// FSSes loaded by SwiftNASR.
  public var FSSes: [FSS]? {
    didSet {
      guard FSSes != nil else { return }
      for FSSIndex in 0..<FSSes!.count {
        FSSes![FSSIndex].data = self
        let findStateByName = FSSes![FSSIndex].findStateByName()
        for facilityIndex in 0..<FSSes![FSSIndex].commFacilities.count {
          FSSes![FSSIndex].commFacilities[facilityIndex].findStateByName = findStateByName
        }
      }
    }
  }

  /// Navaids loaded by SwiftNASR.
  public var navaids: [Navaid]? {
    didSet {
      guard navaids != nil else { return }
      for navaidIndex in 0..<navaids!.count {
        navaids![navaidIndex].data = self
        let findStateByCode = navaids![navaidIndex].findStateByCode()
        let findAirportById = navaids![navaidIndex].findAirportById()
        for checkpointIndex in 0..<navaids![navaidIndex].checkpoints.count {
          navaids![navaidIndex].checkpoints[checkpointIndex].findStateByCode = findStateByCode
          navaids![navaidIndex].checkpoints[checkpointIndex].findAirportById = findAirportById
        }
      }
    }
  }

  /// Fixes (reporting points) loaded by SwiftNASR.
  public var fixes: [Fix]? {
    didSet {
      guard fixes != nil else { return }
      for fixIndex in 0..<fixes!.count {
        fixes![fixIndex].data = self
      }
    }
  }

  /// Weather stations (AWOS/ASOS) loaded by SwiftNASR.
  public var weatherStations: [WeatherStation]? {
    didSet {
      guard weatherStations != nil else { return }
      for stationIndex in 0..<weatherStations!.count {
        weatherStations![stationIndex].data = self
      }
    }
  }

  /// Airways loaded by SwiftNASR.
  public var airways: [Airway]? {
    didSet {
      guard airways != nil else { return }
      for airwayIndex in 0..<airways!.count {
        airways![airwayIndex].data = self
      }
    }
  }

  /// ILS facilities loaded by SwiftNASR.
  public var ILSFacilities: [ILS]? {
    didSet {
      guard ILSFacilities != nil else { return }
      for ilsIndex in 0..<ILSFacilities!.count {
        ILSFacilities![ilsIndex].data = self
      }
    }
  }

  /// Terminal communications facilities loaded by SwiftNASR.
  public var terminalCommFacilities: [TerminalCommFacility]? {
    didSet {
      guard terminalCommFacilities != nil else { return }
      for facilityIndex in 0..<terminalCommFacilities!.count {
        terminalCommFacilities![facilityIndex].data = self
      }
    }
  }

  /// Departure/Arrival procedures complete (STARs and DPs) loaded by SwiftNASR.
  /// This contains the complete comprehensive set including multiple main body
  /// procedures and procedures without computer IDs.
  public var departureArrivalProceduresComplete: [DepartureArrivalProcedure]? {
    didSet {
      guard departureArrivalProceduresComplete != nil else { return }
      for index in 0..<departureArrivalProceduresComplete!.count {
        departureArrivalProceduresComplete![index].data = self
      }
    }
  }

  /// Preferred IFR routes loaded by SwiftNASR.
  public var preferredRoutes: [PreferredRoute]? {
    didSet {
      guard preferredRoutes != nil else { return }
      for index in 0..<preferredRoutes!.count {
        preferredRoutes![index].data = self
      }
    }
  }

  /// Published holding patterns loaded by SwiftNASR.
  public var holds: [Hold]? {
    didSet {
      guard holds != nil else { return }
      for index in 0..<holds!.count {
        holds![index].data = self
      }
    }
  }

  /// Weather reporting locations loaded by SwiftNASR.
  public var weatherReportingLocations: [WeatherReportingLocation]? {
    didSet {
      guard weatherReportingLocations != nil else { return }
      for index in 0..<weatherReportingLocations!.count {
        weatherReportingLocations![index].data = self
      }
    }
  }

  /// Parachute jump areas loaded by SwiftNASR.
  public var parachuteJumpAreas: [ParachuteJumpArea]? {
    didSet {
      guard parachuteJumpAreas != nil else { return }
      for pjaIndex in 0..<parachuteJumpAreas!.count {
        parachuteJumpAreas![pjaIndex].data = self
      }
    }
  }

  /// Military training routes loaded by SwiftNASR.
  public var militaryTrainingRoutes: [MilitaryTrainingRoute]? {
    didSet {
      guard militaryTrainingRoutes != nil else { return }
      for mtrIndex in 0..<militaryTrainingRoutes!.count {
        militaryTrainingRoutes![mtrIndex].data = self
      }
    }
  }

  /// Coded departure routes loaded by SwiftNASR.
  public var codedDepartureRoutes: [CodedDepartureRoute]? {
    didSet {
      guard codedDepartureRoutes != nil else { return }
      for cdrIndex in 0..<codedDepartureRoutes!.count {
        codedDepartureRoutes![cdrIndex].data = self
      }
    }
  }

  /// Miscellaneous activity areas loaded by SwiftNASR.
  public var miscActivityAreas: [MiscActivityArea]? {
    didSet {
      guard miscActivityAreas != nil else { return }
      for maaIndex in 0..<miscActivityAreas!.count {
        miscActivityAreas![maaIndex].data = self
      }
    }
  }

  /// ARTCC boundary segments loaded by SwiftNASR.
  public var ARTCCBoundarySegments: [ARTCCBoundarySegment]? {
    didSet {
      guard ARTCCBoundarySegments != nil else { return }
      for arbIndex in 0..<ARTCCBoundarySegments!.count {
        ARTCCBoundarySegments![arbIndex].data = self
      }
    }
  }

  /// FSS communication facilities loaded by SwiftNASR.
  public var FSSCommFacilities: [FSSCommFacility]? {
    didSet {
      guard FSSCommFacilities != nil else { return }
      for comIndex in 0..<FSSCommFacilities!.count {
        FSSCommFacilities![comIndex].data = self
      }
    }
  }

  /// ATS (Air Traffic Service) airways loaded by SwiftNASR.
  public var atsAirways: [ATSAirway]? {
    didSet {
      guard atsAirways != nil else { return }
      for atsIndex in 0..<atsAirways!.count {
        atsAirways![atsIndex].data = self
      }
    }
  }

  /// Location identifiers loaded by SwiftNASR.
  public var locationIdentifiers: [LocationIdentifier]? {
    didSet {
      guard locationIdentifiers != nil else { return }
      for lidIndex in 0..<locationIdentifiers!.count {
        locationIdentifiers![lidIndex].data = self
      }
    }
  }

  func finishParsing(
    cycle: Cycle? = nil,
    states: [State]? = nil,
    airports: [Airport]? = nil,
    ARTCCs: [ARTCC]? = nil,
    FSSes: [FSS]? = nil,
    navaids: [Navaid]? = nil,
    fixes: [Fix]? = nil,
    weatherStations: [WeatherStation]? = nil,
    airways: [Airway]? = nil,
    ILSFacilities: [ILS]? = nil,
    terminalCommFacilities: [TerminalCommFacility]? = nil,
    departureArrivalProceduresComplete: [DepartureArrivalProcedure]? = nil,
    preferredRoutes: [PreferredRoute]? = nil,
    holds: [Hold]? = nil,
    weatherReportingLocations: [WeatherReportingLocation]? = nil,
    parachuteJumpAreas: [ParachuteJumpArea]? = nil,
    militaryTrainingRoutes: [MilitaryTrainingRoute]? = nil,
    codedDepartureRoutes: [CodedDepartureRoute]? = nil,
    miscActivityAreas: [MiscActivityArea]? = nil,
    ARTCCBoundarySegments: [ARTCCBoundarySegment]? = nil,
    FSSCommFacilities: [FSSCommFacility]? = nil,
    atsAirways: [ATSAirway]? = nil,
    locationIdentifiers: [LocationIdentifier]? = nil
  ) {
    if let cycle { self.cycle = cycle }
    if let states { self.states = states }
    if let airports { self.airports = airports }
    if let ARTCCs { self.ARTCCs = ARTCCs }
    if let FSSes { self.FSSes = FSSes }
    if let navaids { self.navaids = navaids }
    if let fixes { self.fixes = fixes }
    if let weatherStations { self.weatherStations = weatherStations }
    if let airways { self.airways = airways }
    if let ILSFacilities { self.ILSFacilities = ILSFacilities }
    if let terminalCommFacilities { self.terminalCommFacilities = terminalCommFacilities }
    if let departureArrivalProceduresComplete {
      self.departureArrivalProceduresComplete = departureArrivalProceduresComplete
    }
    if let preferredRoutes { self.preferredRoutes = preferredRoutes }
    if let holds { self.holds = holds }
    if let weatherReportingLocations { self.weatherReportingLocations = weatherReportingLocations }
    if let parachuteJumpAreas { self.parachuteJumpAreas = parachuteJumpAreas }
    if let militaryTrainingRoutes { self.militaryTrainingRoutes = militaryTrainingRoutes }
    if let codedDepartureRoutes { self.codedDepartureRoutes = codedDepartureRoutes }
    if let miscActivityAreas { self.miscActivityAreas = miscActivityAreas }
    if let ARTCCBoundarySegments { self.ARTCCBoundarySegments = ARTCCBoundarySegments }
    if let FSSCommFacilities { self.FSSCommFacilities = FSSCommFacilities }
    if let atsAirways { self.atsAirways = atsAirways }
    if let locationIdentifiers { self.locationIdentifiers = locationIdentifiers }
  }
}

extension Airport {

  /// The the state the airport is in.
  public var state: State? {
    get async {
      guard let stateCode else { return nil }
      guard let states = await data?.states else { return nil }

      return states.first { $0.postOfficeCode == stateCode }
    }
  }

  /// The state containing the associated county.
  public var countyState: State? {
    get async {
      guard let states = await data?.states else { return nil }
      return states.first { $0.postOfficeCode == countyStateCode }
    }
  }

  /// The ARTCC facilities belonging to the ARTCC whose boundaries contain
  /// this airport.
  public var boundaryARTCCs: [ARTCC]? {
    get async {
      guard let ARTCCs = await data?.ARTCCs else { return nil }
      return ARTCCs.filter { $0.code == boundaryARTCCId }
    }
  }

  /// The ARTCC facilities belonging to the ARTCC that is responsible for
  /// traffic departing from and arriving at this airport.
  public var responsibleARTCCs: [ARTCC]? {
    get async {
      guard let ARTCCs = await data?.ARTCCs else { return nil }
      return ARTCCs.filter { $0.code == responsibleARTCCId }
    }
  }

  /// The tie-in flight service station responsible for this airport.
  public var tieInFSS: FSS? {
    get async {
      guard let FSSes = await data?.FSSes else { return nil }
      return FSSes.first { $0.id == tieInFSSId }
    }
  }

  /// An alternate FSS responsible for this airport when the tie-in FSS is
  /// closed.
  public var alternateFSS: FSS? {
    get async {
      guard let FSSes = await data?.FSSes else { return nil }
      guard let alternateFSSId else { return nil }

      return FSSes.first { $0.id == alternateFSSId }
    }
  }

  /// The FSS responsible for issuing NOTAMs for this airport.
  public var NOTAMIssuer: FSS? {
    get async {
      guard let FSSes = await data?.FSSes else { return nil }
      guard let NOTAMIssuerId else { return nil }

      return FSSes.first { $0.id == NOTAMIssuerId }
    }
  }
}

extension Airport {
  func findRunwayById() -> (@Sendable (_ runwayID: String) -> Runway?) {
    return { runwayID in
      return self.runways.first { $0.identification == runwayID }
    }
  }
}

extension RunwayEnd.LAHSOPoint {

  /// The intersecting runway defining the LAHSO point, if defined by runway.
  public var intersectingRunway: Runway? {
    guard let intersectingRunwayId else { return nil }
    return findRunwayById(intersectingRunwayId)
  }
}

extension ARTCC {

  /// The state containing the Center facility.
  public var state: State? {
    get async {
      guard let stateCode else { return nil }
      guard let states = await data?.states else { return nil }

      return states.first { $0.postOfficeCode == stateCode }
    }
  }

  func findAirportById() -> (@Sendable (_ airportId: String) async -> Airport?) {
    return { airportId in
      guard let airports = await self.data?.airports else { return nil }

      return airports.first { $0.LID == airportId }
    }
  }
}

extension ARTCC.CommFrequency {

  /// The associated airport, if this facility is associated with an airport.
  public var associatedAirport: Airport? {
    get async {
      guard let associatedAirportCode else { return nil }
      return await findAirportById(associatedAirportCode)
    }
  }
}

extension FSS {

  /// The nearest FSS with teletype capability.
  public var nearestFSSWithTeletype: FSS? {
    get async {
      guard let nearestFSSIdWithTeletype else { return nil }
      guard let FSSes = await data?.FSSes else { return nil }

      return FSSes.first { $0.id == nearestFSSIdWithTeletype }
    }
  }

  /// The state associated with the FSS, when the FSS is not located on an
  /// airport.
  public var state: State? {
    get async {
      guard let stateName else { return nil }
      guard let states = await data?.states else { return nil }

      return states.first { $0.name == stateName }
    }
  }

  /// The airport this FSS is associated with, if any.
  public var airport: Airport? {
    get async {
      guard let airportId else { return nil }
      guard let airports = await data?.airports else { return nil }

      return airports.first { $0.id == airportId }
    }
  }
}

extension FSS {
  func findStateByName() -> (@Sendable (_ name: String) async -> State?) {
    return { name in
      guard let states = await self.data?.states else { return nil }
      return states.first { $0.name == name }
    }
  }
}

extension FSS.CommFacility {

  /// The state associated with the comm facility.
  public var state: State? {
    get async {
      guard let stateName else { return nil }
      return await findStateByName(stateName)
    }
  }
}

extension Navaid {
  func findAirportById() -> (@Sendable (_ airportId: String) async -> Airport?) {
    return { airportId in
      guard let airports = await self.data?.airports else { return nil }

      return airports.first { $0.LID == airportId }
    }
  }

  func findStateByCode() -> (@Sendable (_ code: String) async -> State?) {
    return { code in
      guard let states = await self.data?.states else { return nil }
      return states.first { $0.postOfficeCode == code }
    }
  }
}

extension Navaid {

  /// The state associated with the navaid.
  public var state: State? {
    get async {
      await data?.states?.first { $0.name == stateName }
    }
  }

  /// The high-altitude ARTCC containing this navaid.
  public var highAltitudeARTCC: ARTCC? {
    get async {
      guard let highAltitudeARTCCCode else { return nil }
      return await data?.ARTCCs?.first { $0.code == highAltitudeARTCCCode }
    }
  }

  /// The low-altitude ARTCC containing this navaid.
  public var lowAltitudeARTCC: ARTCC? {
    get async {
      guard let lowAltitudeARTCCCode else { return nil }
      return await data?.ARTCCs?.first { $0.code == lowAltitudeARTCCCode }
    }
  }

  /// The FSS that controls this navaid.
  public var controllingFSS: FSS? {
    get async {
      guard let controllingFSSCode else { return nil }
      return await data?.FSSes?.first { $0.id == controllingFSSCode }
    }
  }
}

extension VORCheckpoint {

  /// The state associated with the checkpoint.
  public var state: State? {
    get async {
      return await findStateByCode(stateCode)
    }
  }

  /// The associated airport, if this facility is associated with an airport.
  public var airport: Airport? {
    get async {
      guard let airportId else { return nil }
      return await findAirportById(airportId)
    }
  }
}

extension Fix {

  /// The high-altitude ARTCC with jurisdiction over this fix.
  public var highARTCC: ARTCC? {
    get async {
      guard let highARTCCCode else { return nil }
      return await data?.ARTCCs?.first { $0.code == highARTCCCode }
    }
  }

  /// The low-altitude ARTCC with jurisdiction over this fix.
  public var lowARTCC: ARTCC? {
    get async {
      guard let lowARTCCCode else { return nil }
      return await data?.ARTCCs?.first { $0.code == lowARTCCCode }
    }
  }
}

extension WeatherStation {

  /// The airport where this weather station is located, if any.
  public var airport: Airport? {
    get async {
      guard let airportSiteNumber else { return nil }
      return await data?.airports?.first { $0.id == airportSiteNumber }
    }
  }
}

extension Airway {

  /// Resolves the ARTCC for a segment by its ID.
  func resolveARTCC(_ artccID: String?) async -> ARTCC? {
    guard let artccID else { return nil }
    return await data?.ARTCCs?.first { $0.code == artccID }
  }
}

extension ILS {

  /// The airport where this ILS is located.
  public var airport: Airport? {
    get async {
      return await data?.airports?.first { $0.id == airportSiteNumber }
    }
  }
}

extension TerminalCommFacility {

  /// The airport where this terminal comm facility is located, if any.
  public var airport: Airport? {
    get async {
      guard let airportSiteNumber else { return nil }
      return await data?.airports?.first { $0.id == airportSiteNumber }
    }
  }

  /// The tie-in Flight Service Station, if any.
  public var tieInFSS: FSS? {
    get async {
      guard let tieInFSSId else { return nil }
      return await data?.FSSes?.first { $0.id == tieInFSSId }
    }
  }
}

extension ParachuteJumpArea {

  /// The airport associated with this parachute jump area, if any.
  public var airport: Airport? {
    get async {
      guard let airportSiteNumber else { return nil }
      return await data?.airports?.first { $0.id == airportSiteNumber }
    }
  }

  /// The navaid associated with this parachute jump area, if any.
  public var navaid: Navaid? {
    get async {
      guard let navaidIdentifier else { return nil }
      return await data?.navaids?.first { $0.id == navaidIdentifier }
    }
  }

  /// The FSS associated with this parachute jump area, if any.
  public var fss: FSS? {
    get async {
      guard let FSSIdentifier else { return nil }
      return await data?.FSSes?.first { $0.id == FSSIdentifier }
    }
  }
}

extension MilitaryTrainingRoute {

  /// The ARTCCs associated with this military training route.
  public var artccs: [ARTCC] {
    get async {
      guard let allARTCCs = await data?.ARTCCs else { return [] }
      return allARTCCs.filter { ARTCCIdentifiers.contains($0.code) }
    }
  }

  /// The FSSes within 150 NM of this military training route.
  public var fsses: [FSS] {
    get async {
      guard let allFSSes = await data?.FSSes else { return [] }
      return allFSSes.filter { FSSIdentifiers.contains($0.id) }
    }
  }
}

extension CodedDepartureRoute {

  /// The ARTCC associated with this coded departure route.
  public var artcc: ARTCC? {
    get async {
      await data?.ARTCCs?.first { $0.code == ARTCCIdentifier }
    }
  }
}

extension MiscActivityArea {

  /// The navaid associated with this miscellaneous activity area.
  public var navaid: Navaid? {
    get async {
      guard let navaidIdentifier else { return nil }
      return await data?.navaids?.first { $0.id == navaidIdentifier }
    }
  }

  /// The associated airport for this miscellaneous activity area.
  public var associatedAirport: Airport? {
    get async {
      guard let associatedAirportSiteNumber else { return nil }
      return await data?.airports?.first { $0.id == associatedAirportSiteNumber }
    }
  }
}

extension ARTCCBoundarySegment {

  /// The ARTCC associated with this boundary segment.
  public var artcc: ARTCC? {
    get async {
      return await data?.ARTCCs?.first { $0.code == ARTCCIdentifier }
    }
  }
}

extension FSSCommFacility {

  /// The FSS associated with this communication facility.
  public var fss: FSS? {
    get async {
      guard let FSSIdentifier else { return nil }
      return await data?.FSSes?.first { $0.id == FSSIdentifier }
    }
  }

  /// The alternate FSS associated with this communication facility.
  public var alternateFSS: FSS? {
    get async {
      guard let alternateFSSIdentifier else { return nil }
      return await data?.FSSes?.first { $0.id == alternateFSSIdentifier }
    }
  }

  /// The navaid associated with this communication facility.
  public var navaid: Navaid? {
    get async {
      guard let navaidIdentifier else { return nil }
      return await data?.navaids?.first { $0.id == navaidIdentifier }
    }
  }
}

extension Hold {

  /// The navaid associated with this holding pattern.
  public var navaid: Navaid? {
    get async {
      guard let navaidIdentifier else { return nil }
      guard let navaids = await data?.navaids else { return nil }

      // Match by both identifier and type when type is available
      if let navaidType = navaidFacilityType {
        return navaids.first { $0.id == navaidIdentifier && $0.type == navaidType }
      }
      // Fall back to identifier-only match
      return navaids.first { $0.id == navaidIdentifier }
    }
  }

  /// The ILS facility associated with this holding pattern.
  public var ILSFacility: ILS? {
    get async {
      guard let ILSFacilityIdentifier else { return nil }
      return await data?.ILSFacilities?.first { $0.id == ILSFacilityIdentifier }
    }
  }

  /// The fix associated with this holding pattern.
  public var fix: Fix? {
    get async {
      guard let fixIdentifier else { return nil }
      return await data?.fixes?.first { $0.id == fixIdentifier }
    }
  }

  /// The ARTCC associated with the fix.
  public var fixARTCCReference: ARTCC? {
    get async {
      guard let fixARTCC else { return nil }
      return await data?.ARTCCs?.first { $0.code == fixARTCC }
    }
  }

  /// The high-route ARTCC associated with the navaid.
  public var highRouteARTCC: ARTCC? {
    get async {
      guard let navaidHighRouteARTCC else { return nil }
      return await data?.ARTCCs?.first { $0.code == navaidHighRouteARTCC }
    }
  }

  /// The low-route ARTCC associated with the navaid.
  public var lowRouteARTCC: ARTCC? {
    get async {
      guard let navaidLowRouteARTCC else { return nil }
      return await data?.ARTCCs?.first { $0.code == navaidLowRouteARTCC }
    }
  }

  /// The state associated with the fix.
  public var fixState: State? {
    get async {
      guard let fixStateCode else { return nil }
      return await data?.states?.first { $0.postOfficeCode == fixStateCode }
    }
  }
}

extension PreferredRoute {

  /// The origin location identifier.
  public var originLocation: LocationIdentifier? {
    get async {
      return await data?.locationIdentifiers?.first { $0.id == originIdentifier }
    }
  }

  /// The destination location identifier.
  public var destinationLocation: LocationIdentifier? {
    get async {
      return await data?.locationIdentifiers?.first { $0.id == destinationIdentifier }
    }
  }
}

extension LocationIdentifier {

  /// The controlling ARTCC for this location.
  public var artcc: ARTCC? {
    get async {
      guard let controllingARTCC else { return nil }
      return await data?.ARTCCs?.first { $0.code == controllingARTCC }
    }
  }

  /// The tie-in FSS for the landing facility.
  public var landingFacilityFSSReference: FSS? {
    get async {
      guard let landingFacilityFSS else { return nil }
      return await data?.FSSes?.first { $0.id == landingFacilityFSS }
    }
  }

  /// The tie-in FSS for navaids.
  public var navaidFSSReference: FSS? {
    get async {
      guard let navaidFSS else { return nil }
      return await data?.FSSes?.first { $0.id == navaidFSS }
    }
  }

  /// The airport associated with the ILS.
  public var ILSAirport: Airport? {
    get async {
      guard let ILSAirportIdentifier else { return nil }
      return await data?.airports?.first { $0.LID == ILSAirportIdentifier }
    }
  }

  /// The tie-in FSS for the ILS.
  public var ILSFSSReference: FSS? {
    get async {
      guard let ILSFSS else { return nil }
      return await data?.FSSes?.first { $0.id == ILSFSS }
    }
  }
}

extension WeatherReportingLocation {

  /// The state associated with this weather reporting location.
  public var state: State? {
    get async {
      guard let stateCode else { return nil }
      return await data?.states?.first { $0.postOfficeCode == stateCode }
    }
  }
}

extension ATSAirway {

  /// Returns the ARTCC for the given route point.
  public func artcc(for routePoint: RoutePoint) async -> ARTCC? {
    guard let ARTCCIdentifier = routePoint.ARTCCIdentifier else { return nil }
    return await data?.ARTCCs?.first { $0.code == ARTCCIdentifier }
  }

  /// Returns the navaid for the given route point.
  public func navaid(for routePoint: RoutePoint) async -> Navaid? {
    guard let navaidIdentifier = routePoint.navaidIdentifier else { return nil }
    return await data?.navaids?.first { $0.id == navaidIdentifier }
  }
}

extension DepartureArrivalProcedure {

  /// Returns the airport for the given adapted airport entry.
  public func airport(for adaptedAirport: AdaptedAirport) async -> Airport? {
    await data?.airports?.first { $0.LID == adaptedAirport.identifier }
  }
}

/**
 Because actors cannot yet conform to `Codable`, use this class to encode and
 decode ``NASRData`` instances. See the `NASRData` documentation for information
 on how to encode and decode instances.
 */

public struct NASRDataCodable: Codable {
  var cycle: Cycle?
  var states: [State]?
  var airports: [Airport]?
  var ARTCCs: [ARTCC]?
  var FSSes: [FSS]?
  var navaids: [Navaid]?
  var fixes: [Fix]?
  var weatherStations: [WeatherStation]?
  var airways: [Airway]?
  var ILSFacilities: [ILS]?
  var terminalCommFacilities: [TerminalCommFacility]?
  var departureArrivalProceduresComplete: [DepartureArrivalProcedure]?
  var preferredRoutes: [PreferredRoute]?
  var holds: [Hold]?
  var weatherReportingLocations: [WeatherReportingLocation]?
  var parachuteJumpAreas: [ParachuteJumpArea]?
  var militaryTrainingRoutes: [MilitaryTrainingRoute]?
  var codedDepartureRoutes: [CodedDepartureRoute]?
  var miscActivityAreas: [MiscActivityArea]?
  var ARTCCBoundarySegments: [ARTCCBoundarySegment]?
  var FSSCommFacilities: [FSSCommFacility]?
  var atsAirways: [ATSAirway]?
  var locationIdentifiers: [LocationIdentifier]?

  public init(data: NASRData) async {
    cycle = await data.cycle
    states = await data.states?.sorted { $0.postOfficeCode < $1.postOfficeCode }
    airports = await data.airports?.sorted { $0.id < $1.id }
    ARTCCs = await data.ARTCCs?.sorted { $0.id < $1.id }
    FSSes = await data.FSSes?.sorted { $0.id < $1.id }
    navaids = await data.navaids?.sorted { $0.id < $1.id }
    fixes = await data.fixes?.sorted { $0.id < $1.id }
    weatherStations = await data.weatherStations?.sorted { $0.id < $1.id }
    airways = await data.airways?.sorted { $0.id < $1.id }
    ILSFacilities = await data.ILSFacilities?.sorted { $0.id < $1.id }
    terminalCommFacilities = await data.terminalCommFacilities?.sorted { $0.id < $1.id }
    departureArrivalProceduresComplete = await data.departureArrivalProceduresComplete?
      .sorted { $0.id < $1.id }
    preferredRoutes = await data.preferredRoutes?.sorted { $0.id < $1.id }
    holds = await data.holds?.sorted { $0.id < $1.id }
    weatherReportingLocations = await data.weatherReportingLocations?.sorted { $0.id < $1.id }
    parachuteJumpAreas = await data.parachuteJumpAreas?.sorted { $0.id < $1.id }
    militaryTrainingRoutes = await data.militaryTrainingRoutes?.sorted { $0.id < $1.id }
    codedDepartureRoutes = await data.codedDepartureRoutes?.sorted { $0.id < $1.id }
    miscActivityAreas = await data.miscActivityAreas?.sorted { $0.id < $1.id }
    ARTCCBoundarySegments = await data.ARTCCBoundarySegments?.sorted { $0.id < $1.id }
    FSSCommFacilities = await data.FSSCommFacilities?.sorted { $0.id < $1.id }
    atsAirways = await data.atsAirways?.sorted { $0.id < $1.id }
    locationIdentifiers = await data.locationIdentifiers?.sorted { $0.id < $1.id }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let decodedCycle = try container.decodeIfPresent(Cycle.self, forKey: .cycle)
    let decodedStates = try container.decodeIfPresent(Array<State>.self, forKey: .states)
    let decodedAirports = try container.decodeIfPresent(Array<Airport>.self, forKey: .airports)
    let decodedARTCCs = try container.decodeIfPresent(Array<ARTCC>.self, forKey: .ARTCCs)
    let decodedFSSes = try container.decodeIfPresent(Array<FSS>.self, forKey: .FSSes)
    let decodedNavaids = try container.decodeIfPresent(Array<Navaid>.self, forKey: .navaids)
    let decodedFixes = try container.decodeIfPresent(Array<Fix>.self, forKey: .fixes)
    let decodedWeatherStations = try container.decodeIfPresent(
      Array<WeatherStation>.self,
      forKey: .weatherStations
    )
    let decodedAirways = try container.decodeIfPresent(Array<Airway>.self, forKey: .airways)
    let decodedILSFacilities = try container.decodeIfPresent(
      Array<ILS>.self,
      forKey: .ILSFacilities
    )
    let decodedTerminalCommFacilities = try container.decodeIfPresent(
      Array<TerminalCommFacility>.self,
      forKey: .terminalCommFacilities
    )
    let decodedDepartureArrivalProceduresComplete = try container.decodeIfPresent(
      Array<DepartureArrivalProcedure>.self,
      forKey: .departureArrivalProceduresComplete
    )
    let decodedPreferredRoutes = try container.decodeIfPresent(
      Array<PreferredRoute>.self,
      forKey: .preferredRoutes
    )
    let decodedHolds = try container.decodeIfPresent(Array<Hold>.self, forKey: .holds)
    let decodedWeatherReportingLocations = try container.decodeIfPresent(
      Array<WeatherReportingLocation>.self,
      forKey: .weatherReportingLocations
    )
    let decodedParachuteJumpAreas = try container.decodeIfPresent(
      Array<ParachuteJumpArea>.self,
      forKey: .parachuteJumpAreas
    )
    let decodedMilitaryTrainingRoutes = try container.decodeIfPresent(
      Array<MilitaryTrainingRoute>.self,
      forKey: .militaryTrainingRoutes
    )
    let decodedCodedDepartureRoutes = try container.decodeIfPresent(
      Array<CodedDepartureRoute>.self,
      forKey: .codedDepartureRoutes
    )
    let decodedMiscActivityAreas = try container.decodeIfPresent(
      Array<MiscActivityArea>.self,
      forKey: .miscActivityAreas
    )
    let decodedARTCCBoundarySegments = try container.decodeIfPresent(
      Array<ARTCCBoundarySegment>.self,
      forKey: .ARTCCBoundarySegments
    )
    let decodedFSSCommFacilities = try container.decodeIfPresent(
      Array<FSSCommFacility>.self,
      forKey: .FSSCommFacilities
    )
    let decodedAtsAirways = try container.decodeIfPresent(
      Array<ATSAirway>.self,
      forKey: .atsAirways
    )
    let decodedLocationIdentifiers = try container.decodeIfPresent(
      Array<LocationIdentifier>.self,
      forKey: .locationIdentifiers
    )

    // stick these setters in a defer block so that the didSet hooks get called
    defer {
      cycle = decodedCycle
      states = decodedStates
      airports = decodedAirports
      ARTCCs = decodedARTCCs
      FSSes = decodedFSSes
      navaids = decodedNavaids
      fixes = decodedFixes
      weatherStations = decodedWeatherStations
      airways = decodedAirways
      ILSFacilities = decodedILSFacilities
      terminalCommFacilities = decodedTerminalCommFacilities
      departureArrivalProceduresComplete = decodedDepartureArrivalProceduresComplete
      preferredRoutes = decodedPreferredRoutes
      holds = decodedHolds
      weatherReportingLocations = decodedWeatherReportingLocations
      parachuteJumpAreas = decodedParachuteJumpAreas
      militaryTrainingRoutes = decodedMilitaryTrainingRoutes
      codedDepartureRoutes = decodedCodedDepartureRoutes
      miscActivityAreas = decodedMiscActivityAreas
      ARTCCBoundarySegments = decodedARTCCBoundarySegments
      FSSCommFacilities = decodedFSSCommFacilities
      atsAirways = decodedAtsAirways
      locationIdentifiers = decodedLocationIdentifiers
    }
  }

  public func makeData() async -> NASRData {
    let data = NASRData()
    await data.finishParsing(
      cycle: cycle,
      states: states,
      airports: airports,
      ARTCCs: ARTCCs,
      FSSes: FSSes,
      navaids: navaids,
      fixes: fixes,
      weatherStations: weatherStations,
      airways: airways,
      ILSFacilities: ILSFacilities,
      terminalCommFacilities: terminalCommFacilities,
      departureArrivalProceduresComplete: departureArrivalProceduresComplete,
      preferredRoutes: preferredRoutes,
      holds: holds,
      weatherReportingLocations: weatherReportingLocations,
      parachuteJumpAreas: parachuteJumpAreas,
      militaryTrainingRoutes: militaryTrainingRoutes,
      codedDepartureRoutes: codedDepartureRoutes,
      miscActivityAreas: miscActivityAreas,
      ARTCCBoundarySegments: ARTCCBoundarySegments,
      FSSCommFacilities: FSSCommFacilities,
      atsAirways: atsAirways,
      locationIdentifiers: locationIdentifiers
    )
    return data
  }

  enum CodingKeys: String, CodingKey {
    case cycle, states, airports, ARTCCs, FSSes, navaids, fixes, weatherStations, airways
    case ILSFacilities, terminalCommFacilities, departureArrivalProceduresComplete
    case preferredRoutes, holds, weatherReportingLocations, parachuteJumpAreas
    case militaryTrainingRoutes, codedDepartureRoutes, miscActivityAreas
    case ARTCCBoundarySegments, FSSCommFacilities, atsAirways, locationIdentifiers
  }
}
