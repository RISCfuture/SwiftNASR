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
            } transform: { .init($0)! }
            "-"
            Capture(as: minutesRef) {
                Repeat(.digit, count: 2)
            } transform: { .init($0)! }
            "-"
            Capture(as: secondsRef) {
                Repeat(.digit, count: 2)
                "."
                OneOrMore(.digit)
            } transform: { .init($0)! }
            Capture(as: quadrantRef) { .anyOf("NESW") }
            Anchor.endOfSubject
        }
    }

    func parse(_ string: String) throws -> Float? {
        guard let match = try rx.regex.firstMatch(in: string) else { return nil }

        let degrees = match[degreesRef],
            minutes = match[minutesRef],
            quadrant = match[quadrantRef]
        var seconds = match[secondsRef]

        let sign = (quadrant == "S" || quadrant == "W") ? -1 : 1
        seconds += Double(minutes * 60)
        seconds += Double(degrees * 3600)
        seconds *= Double(sign)

        return Float(seconds)
    }
}
