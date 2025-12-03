import Foundation
@preconcurrency import RegexBuilder

final class FrequencyParser: Sendable {
  private let MHzRef = Reference<UInt>()
  private let kHzRef = Reference<UInt?>()
  private let useRef = Reference<FSS.Frequency.Use?>()
  private let SSBRef = Reference<Bool>()
  private let nameRef = Reference<String?>()

  private var rx: some RegexComponent {
    Regex {
      Anchor.startOfSubject
      Capture(as: MHzRef) {
        OneOrMore(.digit)
      } transform: {
        .init($0)!
      }
      Optionally {
        "."
        Capture(as: kHzRef) {
          OneOrMore(.digit)
        } transform: {
          .init($0)
        }
      }
      Capture(as: useRef) {
        Optionally { .anyOf("TRX") }
      } transform: {
        .init(rawValue: String($0))
      }
      Capture(as: SSBRef) {
        Optionally("(SSB)")
      } transform: {
        $0 == "(SSB)"
      }
      Capture(as: nameRef) {
        Optionally {
          " "
          OneOrMore(.any)
        }
      } transform: {
        $0.trimmingCharacters(in: .whitespaces).presence
      }
      Anchor.endOfSubject
    }
  }

  func parse(_ string: String) throws -> FSS.Frequency {
    guard let match = try rx.regex.firstMatch(in: string) else {
      throw Error.invalidFrequency(string)
    }

    let MHz = match[MHzRef]
    let kHz = match[kHzRef] ?? 0
    let frequency = MHz * 1000 + kHz
    let use = match[useRef]
    let SSB = match[SSBRef]
    let name = match[nameRef]

    return FSS.Frequency(
      frequency: frequency,
      name: name,
      singleSideband: SSB,
      use: use
    )
  }
}
