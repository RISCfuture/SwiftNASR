import SwiftNASR

func verifyAssociations(nasr: NASR, formatName: String, isCSV: Bool) async {
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

  // Airport associations
  if let airports = await nasr.data.airports, !airports.isEmpty {
    // State associations (TXT only - no state parser for CSV)
    if !isCSV {
      // Find an airport with a state code to test state association
      if let airportWithState = airports.first(where: { $0.stateCode != nil }) {
        let state = await airportWithState.state
        check("Airport.state", state != nil)
      }

      // Find an airport with county state code
      if let airport = airports.first(where: { !$0.countyStateCode.isEmpty }) {
        let countyState = await airport.countyState
        check("Airport.countyState", countyState != nil)
      }
    }

    // boundaryARTCCs (TXT only - CSV doesn't have boundaryARTCCId)
    if !isCSV {
      if let airportWithARTCC = airports.first(where: { $0.boundaryARTCCId != nil }) {
        let artccs = await airportWithARTCC.boundaryARTCCs
        check("Airport.boundaryARTCCs", artccs != nil && !artccs!.isEmpty)
      }
    }

    // responsibleARTCCs
    if let airport = airports.first(where: { !$0.responsibleARTCCId.isEmpty }) {
      let artccs = await airport.responsibleARTCCs
      check("Airport.responsibleARTCCs", artccs != nil && !artccs!.isEmpty)
    }

    // tieInFSS
    if let airport = airports.first(where: { !$0.tieInFSSId.isEmpty }) {
      let fss = await airport.tieInFSS
      check("Airport.tieInFSS", fss != nil)
    }

    // alternateFSS (optional)
    if let airport = airports.first(where: { $0.alternateFSSId != nil }) {
      let fss = await airport.alternateFSS
      check("Airport.alternateFSS", fss != nil)
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

  // ARTCC associations
  if let artccs = await nasr.data.ARTCCs, !artccs.isEmpty {
    // State association (TXT only)
    if !isCSV {
      if let artccWithState = artccs.first(where: { $0.stateCode != nil }) {
        let state = await artccWithState.state
        check("ARTCC.state", state != nil)
      }
    }

    // CommFrequency.associatedAirport
    for artcc in artccs {
      if let freq = artcc.frequencies.first(where: { $0.associatedAirportCode != nil }) {
        let airport = await freq.associatedAirport
        check("ARTCC.CommFrequency.associatedAirport", airport != nil)
        break
      }
    }
  }

  // FSS associations
  if let fsses = await nasr.data.FSSes, !fsses.isEmpty {
    // nearestFSSWithTeletype
    if let fss = fsses.first(where: { $0.nearestFSSIdWithTeletype != nil }) {
      let nearestFSS = await fss.nearestFSSWithTeletype
      check("FSS.nearestFSSWithTeletype", nearestFSS != nil)
    }

    // State associations (TXT only)
    if !isCSV {
      // state
      if let fss = fsses.first(where: { $0.stateName != nil }) {
        let state = await fss.state
        check("FSS.state", state != nil)
      }

      // CommFacility.state
      for fss in fsses {
        if let facility = fss.commFacilities.first(where: { $0.stateName != nil }) {
          let state = await facility.state
          check("FSS.CommFacility.state", state != nil)
          break
        }
      }
    }

    // airport
    if let fss = fsses.first(where: { $0.airportId != nil }) {
      let airport = await fss.airport
      check("FSS.airport", airport != nil)
    }
  }

  // Navaid associations
  if let navaids = await nasr.data.navaids, !navaids.isEmpty {
    // state (TXT only)
    if !isCSV {
      if let navaid = navaids.first(where: { $0.stateName != nil }) {
        let state = await navaid.state
        check("Navaid.state", state != nil)
      }
    }

    // highAltitudeARTCC - test first 100 navaids to find one with an association
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

    // controllingFSS
    var foundControllingFSS = false
    for navaid in navaids.prefix(100) where !foundControllingFSS {
      foundControllingFSS = await navaid.controllingFSS != nil
    }
    check("Navaid.controllingFSS", foundControllingFSS)

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
    var foundCheckpointAirport = false
    for navaid in navaids where !foundCheckpointAirport {
      for checkpoint in navaid.checkpoints where !foundCheckpointAirport {
        foundCheckpointAirport = await checkpoint.airport != nil
      }
    }
    check("VORCheckpoint.airport", foundCheckpointAirport)
  }

  // Fix associations
  if let fixes = await nasr.data.fixes, !fixes.isEmpty {
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

  // WeatherStation associations
  if let stations = await nasr.data.weatherStations, !stations.isEmpty {
    if let station = stations.first(where: { $0.airportSiteNumber != nil }) {
      let airport = await station.airport
      check("WeatherStation.airport", airport != nil)
    }
  }

  // ILS associations
  if let ilsFacilities = await nasr.data.ILSFacilities, !ilsFacilities.isEmpty {
    if let ils = ilsFacilities.first {
      let airport = await ils.airport
      check("ILS.airport", airport != nil)
    }
  }

  // TerminalCommFacility associations
  if let facilities = await nasr.data.terminalCommFacilities, !facilities.isEmpty {
    if let facility = facilities.first(where: { $0.airportSiteNumber != nil }) {
      let airport = await facility.airport
      check("TerminalCommFacility.airport", airport != nil)
    }

    if let facility = facilities.first(where: { $0.tieInFSSId != nil }) {
      let fss = await facility.tieInFSS
      check("TerminalCommFacility.tieInFSS", fss != nil)
    }
  }

  // TXT-only associations
  if !isCSV {
    // ParachuteJumpArea associations
    if let pjas = await nasr.data.parachuteJumpAreas, !pjas.isEmpty {
      if let pja = pjas.first(where: { $0.airportSiteNumber != nil }) {
        let airport = await pja.airport
        check("ParachuteJumpArea.airport", airport != nil)
      }

      if let pja = pjas.first(where: { $0.navaidIdentifier != nil }) {
        let navaid = await pja.navaid
        check("ParachuteJumpArea.navaid", navaid != nil)
      }

      if let pja = pjas.first(where: { $0.FSSIdentifier != nil }) {
        let fss = await pja.fss
        check("ParachuteJumpArea.fss", fss != nil)
      }
    }

    // MilitaryTrainingRoute associations
    if let mtrs = await nasr.data.militaryTrainingRoutes, !mtrs.isEmpty {
      if let mtr = mtrs.first(where: { !$0.ARTCCIdentifiers.isEmpty }) {
        let artccs = await mtr.artccs
        check("MilitaryTrainingRoute.artccs", !artccs.isEmpty)
      }

      if let mtr = mtrs.first(where: { !$0.FSSIdentifiers.isEmpty }) {
        let fsses = await mtr.fsses
        check("MilitaryTrainingRoute.fsses", !fsses.isEmpty)
      }
    }

    // MiscActivityArea associations
    if let maas = await nasr.data.miscActivityAreas, !maas.isEmpty {
      if let maa = maas.first(where: { $0.navaidIdentifier != nil }) {
        let navaid = await maa.navaid
        check("MiscActivityArea.navaid", navaid != nil)
      }

      if let maa = maas.first(where: { $0.associatedAirportSiteNumber != nil }) {
        let airport = await maa.associatedAirport
        check("MiscActivityArea.associatedAirport", airport != nil)
      }
    }

    // ARTCCBoundarySegment associations
    if let segments = await nasr.data.ARTCCBoundarySegments, !segments.isEmpty {
      if let segment = segments.first {
        let artcc = await segment.artcc
        check("ARTCCBoundarySegment.artcc", artcc != nil)
      }
    }

    // FSSCommFacility associations
    if let facilities = await nasr.data.FSSCommFacilities, !facilities.isEmpty {
      if let facility = facilities.first(where: { $0.FSSIdentifier != nil }) {
        let fss = await facility.fss
        check("FSSCommFacility.fss", fss != nil)
      }

      if let facility = facilities.first(where: { $0.alternateFSSIdentifier != nil }) {
        let fss = await facility.alternateFSS
        check("FSSCommFacility.alternateFSS", fss != nil)
      }

      if let facility = facilities.first(where: { $0.navaidIdentifier != nil }) {
        let navaid = await facility.navaid
        check("FSSCommFacility.navaid", navaid != nil)
      }
    }

    // Hold associations
    if let holds = await nasr.data.holds, !holds.isEmpty {
      if let hold = holds.first(where: { $0.navaidIdentifier != nil }) {
        let navaid = await hold.navaid
        check("Hold.navaid", navaid != nil)
      }

      if let hold = holds.first(where: { $0.fixIdentifier != nil }) {
        let fix = await hold.fix
        check("Hold.fix", fix != nil)
      }

      if let hold = holds.first(where: { $0.fixARTCC != nil }) {
        let artcc = await hold.fixARTCCReference
        check("Hold.fixARTCCReference", artcc != nil)
      }

      if let hold = holds.first(where: { $0.fixStateCode != nil }) {
        let state = await hold.fixState
        check("Hold.fixState", state != nil)
      }
    }

    // PreferredRoute associations
    if let routes = await nasr.data.preferredRoutes, !routes.isEmpty {
      if let route = routes.first {
        let origin = await route.originLocation
        check("PreferredRoute.originLocation", origin != nil)

        let destination = await route.destinationLocation
        check("PreferredRoute.destinationLocation", destination != nil)
      }
    }

    // LocationIdentifier associations
    if let lids = await nasr.data.locationIdentifiers, !lids.isEmpty {
      if let lid = lids.first(where: { $0.controllingARTCC != nil }) {
        let artcc = await lid.artcc
        check("LocationIdentifier.artcc", artcc != nil)
      }

      if let lid = lids.first(where: { $0.landingFacilityFSS != nil }) {
        let fss = await lid.landingFacilityFSSReference
        check("LocationIdentifier.landingFacilityFSSReference", fss != nil)
      }
    }

    // WeatherReportingLocation associations
    if let locations = await nasr.data.weatherReportingLocations, !locations.isEmpty {
      if let location = locations.first(where: { $0.stateCode != nil }) {
        let state = await location.state
        check("WeatherReportingLocation.state", state != nil)
      }
    }

    // ATSAirway associations
    if let airways = await nasr.data.atsAirways, !airways.isEmpty {
      for airway in airways {
        if let routePoint = airway.routePoints.first(where: { $0.ARTCCIdentifier != nil }) {
          let artcc = await airway.artcc(for: routePoint)
          check("ATSAirway.artcc(for:)", artcc != nil)
          break
        }
      }

      for airway in airways {
        if let routePoint = airway.routePoints.first(where: { $0.navaidIdentifier != nil }) {
          let navaid = await airway.navaid(for: routePoint)
          check("ATSAirway.navaid(for:)", navaid != nil)
          break
        }
      }
    }

    // DepartureArrivalProcedure associations
    if let procedures = await nasr.data.departureArrivalProceduresComplete, !procedures.isEmpty {
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
    // CodedDepartureRoute associations
    if let cdrs = await nasr.data.codedDepartureRoutes, !cdrs.isEmpty {
      if let cdr = cdrs.first {
        let artcc = await cdr.artcc
        check("CodedDepartureRoute.artcc", artcc != nil)
      }
    }
  }

  // Print results
  print("\n=== Association Verification (\(formatName)) ===")
  print("Passed: \(successes.count)")
  if !failures.isEmpty {
    print("Failed: \(failures.count)")
    for failure in failures {
      print("  - \(failure)")
    }
  } else {
    print("All association tests passed!")
  }
}
