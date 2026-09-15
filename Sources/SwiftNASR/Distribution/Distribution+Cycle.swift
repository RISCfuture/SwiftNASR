import Foundation

/// Parses the effective date as the distribution README spells it (e.g. `October 30, 2025`).
let readmeCycleDateStrategy = Date.ParseStrategy(
  format: "\(month: .wide) \(day: .defaultDigits), \(year: .defaultDigits)",
  locale: Locale(identifier: "en_US"),
  timeZone: zulu,
  calendar: Calendar(identifier: .gregorian)
)

/// Renders a cycle date back into the README's spelling, for validating a parse.
private var readmeCycleDateStyle: Date.FormatStyle {
  Date.FormatStyle(
    date: .long,
    locale: Locale(identifier: "en_US"),
    calendar: Calendar(identifier: .gregorian),
    timeZone: zulu
  )
  .month(.wide)
  .day(.defaultDigits)
  .year(.defaultDigits)
}

/// Parses a README effective date, rejecting anything the README would not have written.
///
/// `Date.ParseStrategy` is lenient in two ways this format cannot tolerate: it rolls out-of-range
/// components over, reading `October 32, 2025` as November 1st, and it stops at the first match,
/// accepting trailing text. Both would yield a plausible but wrong ``Cycle``, which callers turn
/// straight into a download URL. Re-rendering the result and requiring it to equal the input
/// rejects both, while still tolerating surrounding whitespace.
func parseReadmeCycleDate(_ string: String) -> Date? {
  let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
  guard let date = try? readmeCycleDateStrategy.parse(trimmed),
    readmeCycleDateStyle.format(date) == trimmed
  else { return nil }
  return date
}

extension Distribution {
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
      progress: nil,
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
    guard let cycleDate = parseReadmeCycleDate(cycleDateString) else {
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
