extension FixedWidthAirportParser {
  private var attendanceTransformer: FixedWidthTransformer {
    .init([
      .recordType,  // 0 record type
      .string(),  // 1 site number
      .string(nullable: .blank),  // 2 state post office code
      .unsignedInteger(),  // 3 sequence number
      .string(),  // 4 attendance schedule
      .null  // 5 blank
    ])
  }

  func parseAttendanceRecord(_ values: [String]) throws {
    if values[4].trimmingCharacters(in: .whitespaces).isEmpty { return }
    let t = try attendanceTransformer.applyTo(values)

    let airportID: String = try t[1]
    guard var airport = airports[airportID] else { return }
    let schedule: String = try t[4]
    airport.attendanceSchedule.append(parseAttendanceSchedule(schedule))
    airports[airportID] = airport
  }

  private func parseAttendanceSchedule(_ value: String) -> AttendanceSchedule {
    let components = value.split(separator: "/")
    if components.count == 3 {
      return .components(
        monthly: String(components[0]),
        daily: String(components[1]),
        hourly: String(components[2])
      )
    }
    return .custom(value)
  }
}
