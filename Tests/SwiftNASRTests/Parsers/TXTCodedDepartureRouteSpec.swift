import Foundation
import Nimble
import Quick

@testable import SwiftNASR

/// Verifies the TXT (comma-delimited, headerless) coded-departure-route parser. The
/// TXT loader feeds one line per `parse(data:)` call; each line has six fields and the
/// six CSV-only fields are left `nil`. Lines with too few fields are dropped with a
/// diagnostic rather than aborting the parse.
final class TXTCodedDepartureRouteSpec: AsyncSpec {
  override static func spec() {
    it("parses six comma-separated fields per line and drops malformed lines") {
      let tempdir = FileManager.default.temporaryDirectory.appendingPathComponent(
        ProcessInfo().globallyUniqueString
      )
      try FileManager.default.createDirectory(at: tempdir, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: tempdir) }

      let parser = TXTCodedDepartureRouteParser()
      let distribution = DirectoryDistribution(location: tempdir, format: .txt)
      try await parser.prepare(distribution: distribution)

      // The loader yields one newline-stripped line at a time.
      let lines = [
        "ABECLTGV,KABE,KCLT,LRP,KABE LRP EMI GVE AIROW CHSLY7 KCLT,ZNY",
        "ABQASESK,KABQ,KASE,RSK,KABQ LARGO3 RSK SLIPY LOYYD1 KASE,ZAB",
        "BADLINE,ONLY,THREE"  // fewer than six fields → dropped
      ]
      for line in lines {
        try await parser.parse(data: Data(line.utf8))
      }

      let routes = await parser.routes
      expect(routes).to(haveCount(2))

      let route = routes["ABECLTGV"]
      expect(route?.origin).to(equal("KABE"))
      expect(route?.destination).to(equal("KCLT"))
      expect(route?.departureFix).to(equal("LRP"))
      // The route string keeps its internal spaces and stays a single field.
      expect(route?.routeString).to(equal("KABE LRP EMI GVE AIROW CHSLY7 KCLT"))
      expect(route?.departureCenterIdentifier).to(equal("ZNY"))

      // The six fields present only in CSV are nil when parsed from TXT.
      expect(route?.arrivalCenterIdentifier).to(beNil())
      expect(route?.transitionCenterIdentifiers).to(beNil())
      expect(route?.coordinationRequired).to(beNil())
      expect(route?.playInfo).to(beNil())
      expect(route?.navigationEquipment).to(beNil())
      expect(route?.lengthNM).to(beNil())

      let diagnostics = await parser.takeDiagnostics()
      expect(diagnostics).to(haveCount(1))
      guard case .recordError = diagnostics[0] else { fail("expected .recordError"); return }
    }
  }
}
