import ArgumentParser
import Foundation
import SwiftNASR

/// The `--format` argument: one distribution format, or both.
enum FormatSelection: String, CaseIterable, ExpressibleByArgument {
  case txt, csv, both

  /// The formats to run, TXT first so output and report ordering never varies.
  var formats: [DataFormat] {
    switch self {
      case .txt: [.txt]
      case .csv: [.csv]
      case .both: [.txt, .csv]
    }
  }

  init?(argument: String) {
    self.init(rawValue: argument.lowercased())
  }
}

/// Parses the `--cycle` argument: `effective`, `next`, or a cycle's effective date as `YYYY-MM-DD`.
///
/// A date that is not the first day of a 28-day cycle is rejected. `Cycle.init(year:month:day:)`
/// accepts one, and it would go on to build a download URL the FAA has no file for.
func parseCycle(_ argument: String) throws -> Cycle {
  switch argument.lowercased() {
    case "effective": return .effective
    case "next":
      guard let next = Cycle.effective.next else {
        throw ValidationError("could not determine the cycle following \(Cycle.effective)")
      }
      return next
    default:
      guard let cycle = Cycle(argument) else {
        throw ValidationError("expected ‘effective’, ‘next’, or a date in YYYY-MM-DD form")
      }
      guard let date = cycle.effectiveDate, let containing = Cycle.effectiveCycle(for: date) else {
        throw ValidationError("that date precedes the earliest cycle SwiftNASR represents")
      }
      guard containing == cycle else {
        throw ValidationError(
          "cycles begin every 28 days; the cycle covering that date is \(containing)"
        )
      }
      return cycle
  }
}
