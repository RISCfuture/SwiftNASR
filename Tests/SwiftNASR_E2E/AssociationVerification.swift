import SwiftNASR

func verifyAssociations(
  nasr: NASR,
  format: DataFormat,
  selectedRecordTypes: Set<RecordType>
) async -> AssociationReport {
  let isCSV = format == .csv
  var failures: [String] = []
  var successes: [String] = []

  // Helper to record results
  func check(_ description: String, _ condition: Bool) {
    if condition {
      successes.append(description)
    } else {
      failures.append(description)
    }
  }

  // Passes if any candidate resolves the association. Records legitimately reference facilities
  // the distribution does not contain — 87 of the 99 airports naming a responsible ARTCC name a
  // Canadian one — so resting the check on whichever element the collection happened to yield
  // first makes it fail at random. A check with no candidates at all is recorded as neither a
  // pass nor a failure.
  func check<T>(
    _ description: String,
    anyOf candidates: some Sequence<T>,
    resolves: (T) async -> Bool
  ) async {
    var sawCandidate = false
    for candidate in candidates {
      sawCandidate = true
      if await resolves(candidate) {
        check(description, true)
        return
      }
    }
    if sawCandidate { check(description, false) }
  }

  // Helper to check if record types are available for association testing
  func canTest(_ types: RecordType...) -> Bool {
    types.allSatisfy { selectedRecordTypes.contains($0) }
  }

  // Airport associations
  if canTest(.airports), let airports = await nasr.data.airports, !airports.isEmpty {
    // State associations (TXT only - no state parser for CSV)
    if !isCSV {
      // Find an airport with a state code to test state association
      await check("Airport.state", anyOf: airports.lazy.filter { $0.stateCode != nil }) {
        airportWithState in
        let state = await airportWithState.state
        return state != nil
      }

      // Find an airport with county state code
      await check(
        "Airport.countyState",
        anyOf: airports.lazy.filter { !$0.countyStateCode.isEmpty }
      ) { airport in
        let countyState = await airport.countyState
        return countyState != nil
      }
    }

    // boundaryARTCCs (TXT only - CSV doesn't have boundaryARTCCId)
    if !isCSV, canTest(.ARTCCFacilities) {
      await check(
        "Airport.boundaryARTCCs",
        anyOf: airports.lazy.filter { $0.boundaryARTCCId != nil }
      ) { airportWithARTCC in
        let artccs = await airportWithARTCC.boundaryARTCCs
        return artccs != nil && !artccs!.isEmpty
      }
    }

    // responsibleARTCCs
    if canTest(.ARTCCFacilities) {
      await check(
        "Airport.responsibleARTCCs",
        anyOf: airports.lazy.filter { !$0.responsibleARTCCId.isEmpty }
      ) { airport in
        let artccs = await airport.responsibleARTCCs
        return artccs != nil && !artccs!.isEmpty
      }
    }

    // tieInFSS
    if canTest(.flightServiceStations) {
      await check("Airport.tieInFSS", anyOf: airports.lazy.filter { !$0.tieInFSSId.isEmpty }) {
        airport in
        let fss = await airport.tieInFSS
        return fss != nil
      }

      // alternateFSS (optional)
      await check("Airport.alternateFSS", anyOf: airports.lazy.filter { $0.alternateFSSId != nil })
      { airport in
        let fss = await airport.alternateFSS
        return fss != nil
      }

      // NOTAMIssuer (optional) - iterate to find an airport with a valid FSS match
      // Some airports issue their own NOTAMs (NOTAMIssuerId = airport LID, not FSS ID)
      var foundNOTAMIssuer = false
      for airport in airports where !foundNOTAMIssuer {
        if airport.NOTAMIssuerId != nil {
          foundNOTAMIssuer = await airport.NOTAMIssuer != nil
        }
      }
      check("Airport.NOTAMIssuer", foundNOTAMIssuer)
    }
  }

  // ARTCC associations
  if canTest(.ARTCCFacilities), let artccs = await nasr.data.ARTCCs, !artccs.isEmpty {
    // State association (TXT only)
    if !isCSV {
      await check("ARTCC.state", anyOf: artccs.lazy.filter { $0.stateCode != nil }) {
        artccWithState in
        let state = await artccWithState.state
        return state != nil
      }
    }

    // CommFrequency.associatedAirport
    if canTest(.airports) {
      await check(
        "ARTCC.CommFrequency.associatedAirport",
        anyOf: artccs.lazy.flatMap(\.frequencies).filter { $0.associatedAirportCode != nil }
      ) { frequency in
        let airport = await frequency.associatedAirport
        return airport != nil
      }
    }
  }

  // FSS associations
  if canTest(.flightServiceStations), let fsses = await nasr.data.FSSes, !fsses.isEmpty {
    // nearestFSSWithTeletype
    await check(
      "FSS.nearestFSSWithTeletype",
      anyOf: fsses.lazy.filter { $0.nearestFSSIdWithTeletype != nil }
    ) { fss in
      let nearestFSS = await fss.nearestFSSWithTeletype
      return nearestFSS != nil
    }

    // State associations (TXT only)
    if !isCSV {
      // state
      await check("FSS.state", anyOf: fsses.lazy.filter { $0.stateName != nil }) { fss in
        let state = await fss.state
        return state != nil
      }

      // CommFacility.state
      await check(
        "FSS.CommFacility.state",
        anyOf: fsses.lazy.flatMap(\.commFacilities).filter { $0.stateName != nil }
      ) { facility in
        let state = await facility.state
        return state != nil
      }
    }

    // airport
    if canTest(.airports) {
      await check("FSS.airport", anyOf: fsses.lazy.filter { $0.airportId != nil }) { fss in
        let airport = await fss.airport
        return airport != nil
      }
    }
  }

  // Navaid associations
  if canTest(.navaids), let navaids = await nasr.data.navaids, !navaids.isEmpty {
    // state (TXT only)
    if !isCSV {
      await check("Navaid.state", anyOf: navaids.lazy.filter { $0.stateName != nil }) { navaid in
        let state = await navaid.state
        return state != nil
      }
    }

    // highAltitudeARTCC - test first 100 navaids to find one with an association
    if canTest(.ARTCCFacilities) {
      var foundHighAltitudeARTCC = false
      for navaid in navaids.prefix(100) where !foundHighAltitudeARTCC {
        foundHighAltitudeARTCC = await navaid.highAltitudeARTCC != nil
      }
      check("Navaid.highAltitudeARTCC", foundHighAltitudeARTCC)

      // lowAltitudeARTCC
      var foundLowAltitudeARTCC = false
      for navaid in navaids.prefix(100) where !foundLowAltitudeARTCC {
        foundLowAltitudeARTCC = await navaid.lowAltitudeARTCC != nil
      }
      check("Navaid.lowAltitudeARTCC", foundLowAltitudeARTCC)
    }

    // controllingFSS
    if canTest(.flightServiceStations) {
      var foundControllingFSS = false
      for navaid in navaids.prefix(100) where !foundControllingFSS {
        foundControllingFSS = await navaid.controllingFSS != nil
      }
      check("Navaid.controllingFSS", foundControllingFSS)
    }

    // VORCheckpoint.state (TXT only)
    if !isCSV {
      for navaid in navaids {
        if let checkpoint = navaid.checkpoints.first {
          let state = await checkpoint.state
          check("VORCheckpoint.state", state != nil)
          break
        }
      }
    }

    // VORCheckpoint.airport
    if canTest(.airports) {
      var foundCheckpointAirport = false
      for navaid in navaids where !foundCheckpointAirport {
        for checkpoint in navaid.checkpoints where !foundCheckpointAirport {
          foundCheckpointAirport = await checkpoint.airport != nil
        }
      }
      check("VORCheckpoint.airport", foundCheckpointAirport)
    }
  }

  // Fix associations
  if canTest(.reportingPoints), let fixes = await nasr.data.fixes, !fixes.isEmpty {
    if canTest(.ARTCCFacilities) {
      // highARTCC
      var foundHighARTCC = false
      for fix in fixes.prefix(100) where !foundHighARTCC {
        foundHighARTCC = await fix.highARTCC != nil
      }
      check("Fix.highARTCC", foundHighARTCC)

      // lowARTCC
      var foundLowARTCC = false
      for fix in fixes.prefix(100) where !foundLowARTCC {
        foundLowARTCC = await fix.lowARTCC != nil
      }
      check("Fix.lowARTCC", foundLowARTCC)
    }
  }

  // WeatherStation associations
  if canTest(.weatherReportingStations, .airports), let stations = await nasr.data.weatherStations,
    !stations.isEmpty
  {
    await check(
      "WeatherStation.airport",
      anyOf: stations.lazy.filter { $0.airportSiteNumber != nil }
    ) { station in
      let airport = await station.airport
      return airport != nil
    }
  }

  // ILS associations
  if canTest(.ILSes, .airports), let ilsFacilities = await nasr.data.ILSFacilities,
    !ilsFacilities.isEmpty
  {
    if let ils = ilsFacilities.first {
      let airport = await ils.airport
      check("ILS.airport", airport != nil)
    }
  }

  // TerminalCommFacility associations
  if canTest(.terminalCommFacilities), let facilities = await nasr.data.terminalCommFacilities,
    !facilities.isEmpty
  {
    if canTest(.airports) {
      await check(
        "TerminalCommFacility.airport",
        anyOf: facilities.lazy.filter { $0.airportSiteNumber != nil }
      ) { facility in
        let airport = await facility.airport
        return airport != nil
      }
    }

    if canTest(.flightServiceStations) {
      await check(
        "TerminalCommFacility.tieInFSS",
        anyOf: facilities.lazy.filter { $0.tieInFSSId != nil }
      ) { facility in
        let fss = await facility.tieInFSS
        return fss != nil
      }
    }
  }

  // TXT-only associations
  if !isCSV {
    // ParachuteJumpArea associations
    if canTest(.parachuteJumpAreas), let pjas = await nasr.data.parachuteJumpAreas, !pjas.isEmpty {
      if canTest(.airports) {
        await check(
          "ParachuteJumpArea.airport",
          anyOf: pjas.lazy.filter { $0.airportSiteNumber != nil }
        ) { pja in
          let airport = await pja.airport
          return airport != nil
        }
      }

      if canTest(.navaids) {
        await check(
          "ParachuteJumpArea.navaid",
          anyOf: pjas.lazy.filter { $0.navaidIdentifier != nil }
        ) { pja in
          let navaid = await pja.navaid
          return navaid != nil
        }
      }

      if canTest(.flightServiceStations) {
        await check("ParachuteJumpArea.fss", anyOf: pjas.lazy.filter { $0.FSSIdentifier != nil }) {
          pja in
          let fss = await pja.fss
          return fss != nil
        }
      }
    }

    // MilitaryTrainingRoute associations
    if canTest(.militaryTrainingRoutes), let mtrs = await nasr.data.militaryTrainingRoutes,
      !mtrs.isEmpty
    {
      if canTest(.ARTCCFacilities) {
        await check(
          "MilitaryTrainingRoute.artccs",
          anyOf: mtrs.lazy.filter { !$0.ARTCCIdentifiers.isEmpty }
        ) { mtr in
          let artccs = await mtr.artccs
          return !artccs.isEmpty
        }
      }

      if canTest(.flightServiceStations) {
        await check(
          "MilitaryTrainingRoute.fsses",
          anyOf: mtrs.lazy.filter { !$0.FSSIdentifiers.isEmpty }
        ) { mtr in
          let fsses = await mtr.fsses
          return !fsses.isEmpty
        }
      }
    }

    // MiscActivityArea associations
    if canTest(.miscActivityAreas), let maas = await nasr.data.miscActivityAreas, !maas.isEmpty {
      if canTest(.navaids) {
        await check(
          "MiscActivityArea.navaid",
          anyOf: maas.lazy.filter { $0.navaidIdentifier != nil }
        ) { maa in
          let navaid = await maa.navaid
          return navaid != nil
        }
      }

      if canTest(.airports) {
        await check(
          "MiscActivityArea.associatedAirport",
          anyOf: maas.lazy.filter { $0.associatedAirportSiteNumber != nil }
        ) { maa in
          let airport = await maa.associatedAirport
          return airport != nil
        }
      }
    }

    // ARTCCBoundarySegment associations
    if canTest(.ARTCCBoundarySegments, .ARTCCFacilities),
      let segments = await nasr.data.ARTCCBoundarySegments, !segments.isEmpty
    {
      if let segment = segments.first {
        let artcc = await segment.artcc
        check("ARTCCBoundarySegment.artcc", artcc != nil)
      }
    }

    // FSSCommFacility associations
    if canTest(.FSSCommFacilities), let facilities = await nasr.data.FSSCommFacilities,
      !facilities.isEmpty
    {
      if canTest(.flightServiceStations) {
        await check(
          "FSSCommFacility.fss",
          anyOf: facilities.lazy.filter { $0.FSSIdentifier != nil }
        ) { facility in
          let fss = await facility.fss
          return fss != nil
        }

        await check(
          "FSSCommFacility.alternateFSS",
          anyOf: facilities.lazy.filter { $0.alternateFSSIdentifier != nil }
        ) { facility in
          let fss = await facility.alternateFSS
          return fss != nil
        }
      }

      if canTest(.navaids) {
        await check(
          "FSSCommFacility.navaid",
          anyOf: facilities.lazy.filter { $0.navaidIdentifier != nil }
        ) { facility in
          let navaid = await facility.navaid
          return navaid != nil
        }
      }
    }

    // Hold associations
    if canTest(.holds), let holds = await nasr.data.holds, !holds.isEmpty {
      if canTest(.navaids) {
        await check("Hold.navaid", anyOf: holds.lazy.filter { $0.navaidIdentifier != nil }) {
          hold in
          let navaid = await hold.navaid
          return navaid != nil
        }
      }

      if canTest(.reportingPoints) {
        await check("Hold.fix", anyOf: holds.lazy.filter { $0.fixIdentifier != nil }) { hold in
          let fix = await hold.fix
          return fix != nil
        }
      }

      if canTest(.ARTCCFacilities) {
        await check("Hold.fixARTCCReference", anyOf: holds.lazy.filter { $0.fixARTCC != nil }) {
          hold in
          let artcc = await hold.fixARTCCReference
          return artcc != nil
        }
      }

      await check("Hold.fixState", anyOf: holds.lazy.filter { $0.fixStateCode != nil }) { hold in
        let state = await hold.fixState
        return state != nil
      }
    }

    // PreferredRoute associations. `preferredRoutes` is an array of a
    // dictionary's values, so its order is nondeterministic, and not every
    // origin/destination identifier has a matching LocationIdentifier. Iterate
    // to find a route whose endpoint resolves instead of relying on
    // `routes.first`, which made this check flaky.
    if canTest(.preferredRoutes, .locationIdentifiers),
      let routes = await nasr.data.preferredRoutes, !routes.isEmpty
    {
      var foundOrigin = false
      for route in routes where !foundOrigin {
        foundOrigin = await route.originLocation != nil
      }
      check("PreferredRoute.originLocation", foundOrigin)

      var foundDestination = false
      for route in routes where !foundDestination {
        foundDestination = await route.destinationLocation != nil
      }
      check("PreferredRoute.destinationLocation", foundDestination)
    }

    // LocationIdentifier associations
    if canTest(.locationIdentifiers), let lids = await nasr.data.locationIdentifiers, !lids.isEmpty
    {
      if canTest(.ARTCCFacilities) {
        await check(
          "LocationIdentifier.artcc",
          anyOf: lids.lazy.filter { $0.controllingARTCC != nil }
        ) { lid in
          let artcc = await lid.artcc
          return artcc != nil
        }
      }

      if canTest(.flightServiceStations) {
        await check(
          "LocationIdentifier.landingFacilityFSSReference",
          anyOf: lids.lazy.filter { $0.landingFacilityFSS != nil }
        ) { lid in
          let fss = await lid.landingFacilityFSSReference
          return fss != nil
        }
      }
    }

    // WeatherReportingLocation associations
    if canTest(.weatherReportingLocations),
      let locations = await nasr.data.weatherReportingLocations, !locations.isEmpty
    {
      await check(
        "WeatherReportingLocation.state",
        anyOf: locations.lazy.filter { $0.stateCode != nil }
      ) { location in
        let state = await location.state
        return state != nil
      }
    }

    // ATSAirway associations
    if canTest(.ATSAirways), let airways = await nasr.data.atsAirways, !airways.isEmpty {
      if canTest(.ARTCCFacilities) {
        await check(
          "ATSAirway.artcc(for:)",
          anyOf: airways.lazy.flatMap { airway in
            airway.routePoints.lazy.filter { $0.ARTCCIdentifier != nil }.map { (airway, $0) }
          }
        ) { pair in
          let artcc = await pair.0.artcc(for: pair.1)
          return artcc != nil
        }
      }

      if canTest(.navaids) {
        await check(
          "ATSAirway.navaid(for:)",
          anyOf: airways.lazy.flatMap { airway in
            airway.routePoints.lazy.filter { $0.navaidIdentifier != nil }.map { (airway, $0) }
          }
        ) { pair in
          let navaid = await pair.0.navaid(for: pair.1)
          return navaid != nil
        }
      }
    }

    // DepartureArrivalProcedure associations
    if canTest(.departureArrivalProceduresComplete, .airports),
      let procedures = await nasr.data.departureArrivalProceduresComplete, !procedures.isEmpty
    {
      for procedure in procedures {
        if let adaptedAirport = procedure.adaptedAirports.first {
          let airport = await procedure.airport(for: adaptedAirport)
          check("DepartureArrivalProcedure.airport(for:)", airport != nil)
          break
        }
      }
    }
  }

  // CSV-only associations
  if isCSV {
    // TerminalCommFacility radar/military/airspace data is split into separate CSV
    // files (RDR/MIL_OPS/CLS_ARSP) and folded back in. The TXT format carries these
    // inline, so this completeness check is CSV-only.
    if canTest(.terminalCommFacilities),
      let facilities = await nasr.data.terminalCommFacilities, !facilities.isEmpty
    {
      check(
        "TerminalCommFacility.radar (folded from RDR.csv)",
        facilities.contains { $0.radar != nil }
      )
      check(
        "TerminalCommFacility.airspace (folded from CLS_ARSP.csv)",
        facilities.contains { $0.airspace != nil }
      )
      check(
        "TerminalCommFacility.militaryOperator (folded from MIL_OPS.csv)",
        facilities.contains { $0.militaryOperator != nil }
      )
    }
  }

  // CodedDepartureRoute associations (both formats — CDR now parses in TXT and CSV).
  // `codedDepartureRoutes` is an array of a dictionary's values, so its order is
  // nondeterministic and not every departure center resolves; iterate to find one.
  if canTest(.codedDepartureRoutes, .ARTCCFacilities),
    let cdrs = await nasr.data.codedDepartureRoutes, !cdrs.isEmpty
  {
    var foundARTCC = false
    for cdr in cdrs where !foundARTCC {
      foundARTCC = await cdr.artcc != nil
    }
    check("CodedDepartureRoute.artcc", foundARTCC)
  }

  return AssociationReport(passedCount: successes.count, failures: failures.sorted())
}
