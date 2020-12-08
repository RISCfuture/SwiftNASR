fileprivate let attendanceTransformer = FixedWidthTransformer([
    .recordType,                                                                // 0 record type
    .string(),                                                                  // 1 site number
    .string(nullable: .blank),                                                  // 2 state post office code
    .unsignedInteger(),                                                         // 3 sequence number
    .string(),                                                                  // 4 attendance schedule
    .null                                                                       // 5 blank
])

extension AirportParser {
    func parseAttendanceRecord(_ values: Array<String>) throws {
        if values[4].trimmingCharacters(in: .whitespaces).isEmpty { return }
        let transformedValues = try attendanceTransformer.applyTo(values)
        
        guard let airport = airports[transformedValues[1] as! String] else { return }
        
        airport.attendanceSchedule.append(parseAttendanceSchedule(transformedValues[4] as! String))
    }
    
    private func parseAttendanceSchedule(_ value: String) -> AttendanceSchedule {
        let components = value.split(separator: "/")
        if components.count == 3 {
            return .components(monthly: String(components[0]),
                               daily: String(components[1]),
                               hourly: String(components[2]))
        } else {
            return .custom(value)
        }
    }
}
