import Foundation

extension Distribution {
  private var cycleDateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.timeZone = zulu
    formatter.dateFormat = "MMMM d, yyyy"
    return formatter
  }

  private var readmeFirstLine: Data {
    "AIS subscriber files effective date ".data(using: .isoLatin1)!
  }

  /// Month name to number mapping for CSV parsing
  private var monthMap: [String: Int] {
    [
      "Jan": 1, "Feb": 2, "Mar": 3, "Apr": 4,
      "May": 5, "Jun": 6, "Jul": 7, "Aug": 8,
      "Sep": 9, "Oct": 10, "Nov": 11, "Dec": 12
    ]
  }

  /**
   Default implementation that reads the cycle from the README file.
  
   - Returns: The parsed cycle, or `nil` if the cycle could not be parsed.
   */

  public func readCycle() async throws -> Cycle? {
    let path = try findFile(prefix: "Read_me") ?? "README.txt"

    let lines: AsyncThrowingStream = await readFile(
      path: path,
      withProgress: { _ in },
      returningLines: { _ in }
    )

    for try await line in lines where line.starts(with: readmeFirstLine) {
      return parseCycleFrom(line)
    }
    return nil
  }

  private func parseCycleFrom(_ line: Data) -> Cycle? {
    let cycleDateData = line[readmeFirstLine.count..<(line.count - 1)]
    guard let cycleDateString = String(data: cycleDateData, encoding: .isoLatin1) else {
      return nil
    }
    guard let cycleDate = cycleDateFormatter.date(from: cycleDateString) else {
      return nil
    }

    let cycleComponents = Calendar(identifier: .gregorian).dateComponents(in: zulu, from: cycleDate)
    guard let year = cycleComponents.year else { return nil }
    guard let month = cycleComponents.month else { return nil }
    guard let day = cycleComponents.day else { return nil }

    return Cycle(year: UInt(year), month: UInt8(month), day: UInt8(day))
  }

  /**
   Parses a cycle from a CSV-style date string.
  
   Expected format: DD_MMM_YYYY (e.g., 04_Sep_2025)
  
   - Parameter dateString: The date string to parse
   - Returns: The parsed cycle, or `nil` if the cycle could not be parsed.
   */
  public func parseCycleFromCSVDateString(_ dateString: String) -> Cycle? {
    let components = dateString.split(separator: "_")
    guard components.count >= 3 else { return nil }

    let day = Int(components[0]) ?? 0
    let monthStr = String(components[1])
    let year = Int(components[2]) ?? 0

    guard let month = monthMap[monthStr], day > 0, year > 0 else {
      return nil
    }

    return Cycle(year: UInt(year), month: UInt8(month), day: UInt8(day))
  }
}
