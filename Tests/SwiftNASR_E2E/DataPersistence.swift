import Foundation
import SwiftNASR

func saveData(nasr: NASR, formatName: String, workingDirectory: URL) async {
  await print("\(formatName) - Airports: \(nasr.data.airports?.count ?? 0)")
  await print("\(formatName) - ARTCCs: \(nasr.data.ARTCCs?.count ?? 0)")
  await print("\(formatName) - FSSes: \(nasr.data.FSSes?.count ?? 0)")
  await print("\(formatName) - Navaids: \(nasr.data.navaids?.count ?? 0)")
  await print("\(formatName) - Fixes: \(nasr.data.fixes?.count ?? 0)")
  await print("\(formatName) - Weather Stations: \(nasr.data.weatherStations?.count ?? 0)")
  await print("\(formatName) - Airways: \(nasr.data.airways?.count ?? 0)")
  await print("\(formatName) - ILS Facilities: \(nasr.data.ILSFacilities?.count ?? 0)")
  await print(
    "\(formatName) - Terminal Comm Facilities: \(nasr.data.terminalCommFacilities?.count ?? 0)"
  )
  await print(
    "\(formatName) - Departure/Arrival Procedures Complete: \(nasr.data.departureArrivalProceduresComplete?.count ?? 0)"
  )
  await print("\(formatName) - Preferred Routes: \(nasr.data.preferredRoutes?.count ?? 0)")
  await print("\(formatName) - Holds: \(nasr.data.holds?.count ?? 0)")
  await print(
    "\(formatName) - Weather Reporting Locations: \(nasr.data.weatherReportingLocations?.count ?? 0)"
  )
  await print("\(formatName) - Parachute Jump Areas: \(nasr.data.parachuteJumpAreas?.count ?? 0)")
  await print(
    "\(formatName) - Military Training Routes: \(nasr.data.militaryTrainingRoutes?.count ?? 0)"
  )
  await print(
    "\(formatName) - Coded Departure Routes: \(nasr.data.codedDepartureRoutes?.count ?? 0)"
  )
  await print("\(formatName) - Misc Activity Areas: \(nasr.data.miscActivityAreas?.count ?? 0)")
  await print(
    "\(formatName) - ARTCC Boundary Segments: \(nasr.data.ARTCCBoundarySegments?.count ?? 0)"
  )
  await print("\(formatName) - FSS Comm Facilities: \(nasr.data.FSSCommFacilities?.count ?? 0)")
  await print("\(formatName) - ATS Airways: \(nasr.data.atsAirways?.count ?? 0)")
  await print(
    "\(formatName) - Location Identifiers: \(nasr.data.locationIdentifiers?.count ?? 0)"
  )

  do {
    // Ensure working directory exists
    try FileManager.default.createDirectory(
      at: workingDirectory,
      withIntermediateDirectories: true
    )

    let encoder = JSONZipEncoder()
    let data = try await encoder.encode(NASRDataCodable(data: nasr.data))

    let outPath = workingDirectory.appendingPathComponent(
      "distribution_\(formatName.lowercased()).json.zip"
    )
    try data.write(to: outPath)
    print("\(formatName) JSON file written to \(outPath)")
  } catch {
    print("Error saving \(formatName): \(error)")
  }
}

func verifyCompletion(nasr: NASR, formatName: String, isCSV: Bool) async {
  var missingTypes: [String] = []

  // Check each record type for completion
  if await nasr.data.airports == nil { missingTypes.append("airports") }
  if await nasr.data.ARTCCs == nil { missingTypes.append("ARTCCs") }
  if await nasr.data.FSSes == nil { missingTypes.append("FSSes") }
  if await nasr.data.navaids == nil { missingTypes.append("navaids") }
  if await nasr.data.fixes == nil { missingTypes.append("fixes") }
  if await nasr.data.weatherStations == nil { missingTypes.append("weatherStations") }
  if await nasr.data.airways == nil { missingTypes.append("airways") }
  if await nasr.data.ILSFacilities == nil { missingTypes.append("ILSFacilities") }
  if await nasr.data.terminalCommFacilities == nil {
    missingTypes.append("terminalCommFacilities")
  }
  if await nasr.data.departureArrivalProceduresComplete == nil {
    missingTypes.append("departureArrivalProceduresComplete")
  }
  if await nasr.data.preferredRoutes == nil { missingTypes.append("preferredRoutes") }
  if await nasr.data.holds == nil { missingTypes.append("holds") }
  if await nasr.data.weatherReportingLocations == nil {
    missingTypes.append("weatherReportingLocations")
  }
  if await nasr.data.parachuteJumpAreas == nil { missingTypes.append("parachuteJumpAreas") }
  if await nasr.data.militaryTrainingRoutes == nil {
    missingTypes.append("militaryTrainingRoutes")
  }
  if isCSV {
    if await nasr.data.codedDepartureRoutes == nil {
      missingTypes.append("codedDepartureRoutes")
    }
  }
  if await nasr.data.miscActivityAreas == nil { missingTypes.append("miscActivityAreas") }
  if await nasr.data.ARTCCBoundarySegments == nil { missingTypes.append("ARTCCBoundarySegments") }
  if await nasr.data.FSSCommFacilities == nil { missingTypes.append("FSSCommFacilities") }
  if await nasr.data.atsAirways == nil { missingTypes.append("atsAirways") }
  if await nasr.data.locationIdentifiers == nil { missingTypes.append("locationIdentifiers") }

  if !missingTypes.isEmpty {
    print("\n=== \(formatName) Completion Warning ===")
    print("The following record types failed to parse entirely:")
    for missingType in missingTypes {
      print("  - \(missingType)")
    }
  }
}
