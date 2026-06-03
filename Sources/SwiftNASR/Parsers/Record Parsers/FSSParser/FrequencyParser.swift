import Foundation
@preconcurrency import RegexBuilder

final class FrequencyParser: Sendable {
  private let MHzRef = Reference<UInt>()
  private let fractionRef = Reference<String?>()
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
        Capture(as: fractionRef) {
          OneOrMore(.digit)
        } transform: {
          String($0)
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
    let frequency: UInt
    if let fraction = match[fractionRef] {
      // A decimal point means a VHF/UHF value in MHz; the fractional digits are
      // thousandths of an MHz (kHz), so right-pad to three digits ("5" → 500).
      let kHz = UInt(fraction.padding(toLength: 3, withPad: "0", startingAt: 0)) ?? 0
      frequency = MHz * 1000 + kHz
    } else {
      // No decimal point means an HF value already expressed in kHz (e.g. 8903).
      frequency = MHz
    }
    let use = match[useRef]
    let SSB = match[SSBRef]
    let name = match[nameRef]

    return FSS.Frequency(
      frequencyKHz: frequency,
      name: name,
      singleSideband: SSB,
      use: use
    )
  }
}
