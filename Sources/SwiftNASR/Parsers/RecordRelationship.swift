import Foundation

// Cases rather than strings: the error description is localized, and interpolating an English
// noun into a translated sentence would leave half of it in English.

/// The kind of record that referenced a parent the parser never saw.
enum ChildRecordType: Sendable, CustomStringConvertible {
  case agency
  case airspace
  case altitudeSpeedInfo
  case arrestingSystem
  case ATIS
  case attendanceSchedule
  case changeoverException
  case changeoverPoint
  case chartType
  case chartingInfo
  case NOTAMCheck
  case classAirspace
  case contactFacility
  case continuation
  case DME
  case frequencies
  case glideSlope
  case hours
  case localizer
  case markerBeacon
  case militaryOperations
  case navaidMakeup
  case operatingProcedures
  case pointDescription
  case pointRemark
  case polygonCoordinate
  case radar
  case remark
  case routePoint
  case routeRemark
  case routeWidth
  case runway
  case satelliteAirport
  case segment
  case service
  case terrainFollowing
  case timesOfUse
  case userGroup
  case VORCheckpoint

  var description: String {
    switch self {
      case .agency: return String(localized: "agency")
      case .airspace: return String(localized: "airspace")
      case .altitudeSpeedInfo: return String(localized: "altitude/speed info")
      case .arrestingSystem: return String(localized: "arresting system")
      case .ATIS: return String(localized: "ATIS")
      case .attendanceSchedule: return String(localized: "attendance schedule")
      case .changeoverException: return String(localized: "changeover exception")
      case .changeoverPoint: return String(localized: "changeover point")
      case .chartType: return String(localized: "chart type")
      case .chartingInfo: return String(localized: "charting info")
      case .NOTAMCheck: return String(localized: "check for NOTAMs")
      case .classAirspace: return String(localized: "class airspace")
      case .contactFacility: return String(localized: "contact facility")
      case .continuation: return String(localized: "continuation")
      case .DME: return String(localized: "DME")
      case .frequencies: return String(localized: "frequencies")
      case .glideSlope: return String(localized: "glide slope")
      case .hours: return String(localized: "hours")
      case .localizer: return String(localized: "localizer")
      case .markerBeacon: return String(localized: "marker beacon")
      case .militaryOperations: return String(localized: "military operations")
      case .navaidMakeup: return String(localized: "navaid makeup")
      case .operatingProcedures: return String(localized: "operating procedures")
      case .pointDescription: return String(localized: "point description")
      case .pointRemark: return String(localized: "point remark")
      case .polygonCoordinate: return String(localized: "polygon coordinate")
      case .radar: return String(localized: "radar")
      case .remark: return String(localized: "remark")
      case .routePoint: return String(localized: "route point")
      case .routeRemark: return String(localized: "route remark")
      case .routeWidth: return String(localized: "route width")
      case .runway: return String(localized: "runway")
      case .satelliteAirport: return String(localized: "satellite airport")
      case .segment: return String(localized: "segment")
      case .service: return String(localized: "service")
      case .terrainFollowing: return String(localized: "terrain following")
      case .timesOfUse: return String(localized: "times of use")
      case .userGroup: return String(localized: "user group")
      case .VORCheckpoint: return String(localized: "VOR checkpoint")
    }
  }
}

/// The kind of record a child record referenced.
enum ParentRecordType: Sendable, CustomStringConvertible {
  case airport
  case ATSAirway
  case fix
  case hold
  case ILS
  case militaryTrainingRoute
  case miscActivityArea
  case navaid
  case parachuteJumpArea
  case preferredRoute
  case terminalCommFacility
  case weatherReportingLocation
  case weatherStation

  var description: String {
    switch self {
      case .airport: return String(localized: "airport")
      case .ATSAirway: return String(localized: "ATS airway")
      case .fix: return String(localized: "fix")
      case .hold: return String(localized: "hold")
      case .ILS: return String(localized: "ILS")
      case .militaryTrainingRoute: return String(localized: "military training route")
      case .miscActivityArea: return String(localized: "misc activity area")
      case .navaid: return String(localized: "navaid")
      case .parachuteJumpArea: return String(localized: "parachute jump area")
      case .preferredRoute: return String(localized: "preferred route")
      case .terminalCommFacility: return String(localized: "terminal comm facility")
      case .weatherReportingLocation: return String(localized: "weather reporting location")
      case .weatherStation: return String(localized: "weather station")
    }
  }
}
