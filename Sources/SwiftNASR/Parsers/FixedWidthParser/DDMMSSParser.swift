@preconcurrency import RegexBuilder

final class DDMMSSParser: Sendable {
  private let degreesRef = Reference<Int>()
  private let minutesRef = Reference<Int>()
  private let secondsRef = Reference<Double>()
  private let quadrantRef = Reference<Substring>()
  private var rx: some RegexComponent {
    Regex {
      Anchor.startOfSubject
      Capture(as: degreesRef) {
        Repeat(.digit, 2...3)
      } transform: {
        .init($0)!
      }
      "-"
      Capture(as: minutesRef) {
        Repeat(.digit, count: 2)
      } transform: {
        .init($0)!
      }
      "-"
      Capture(as: secondsRef) {
        Repeat(.digit, count: 2)
        "."
        OneOrMore(.digit)
      } transform: {
        .init($0)!
      }
      Capture(as: quadrantRef) { .anyOf("NESW") }
      Anchor.endOfSubject
    }
  }

  func parse(_ string: String) throws -> Float? {
    guard let match = try rx.regex.firstMatch(in: string) else { return nil }

    let degrees = match[degreesRef]
    let minutes = match[minutesRef]
    let quadrant = match[quadrantRef]
    let seconds = match[secondsRef]

    let sign: Double = (quadrant == "S" || quadrant == "W") ? -1 : 1
    // Convert DMS to arc-seconds: degrees*3600 + minutes*60 + seconds
    let arcSeconds = Double(degrees) * 3600.0 + Double(minutes) * 60.0 + seconds

    return Float(arcSeconds * sign)
  }
}
