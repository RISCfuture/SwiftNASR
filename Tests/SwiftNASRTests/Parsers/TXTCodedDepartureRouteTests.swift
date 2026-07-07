import Foundation
import Testing

@testable import SwiftNASR

/// Verifies the TXT (comma-delimited, headerless) coded-departure-route parser. The
/// TXT loader feeds one line per `parse(data:)` call; each line has six fields and the
/// six CSV-only fields are left `nil`. Lines with too few fields are dropped with a
/// diagnostic rather than aborting the parse.
@Suite
struct TXTCodedDepartureRouteTests {
  @Test
  func parsesSixCommaSeparatedFieldsPerLineAndDropsMalformedLines() async throws {
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
    #expect(routes.count == 2)

    let route = routes["ABECLTGV"]
    #expect(route?.origin == "KABE")
    #expect(route?.destination == "KCLT")
    #expect(route?.departureFix == "LRP")
    // The route string keeps its internal spaces and stays a single field.
    #expect(route?.routeString == "KABE LRP EMI GVE AIROW CHSLY7 KCLT")
    #expect(route?.departureCenterIdentifier == "ZNY")

    // The six fields present only in CSV are nil when parsed from TXT.
    #expect(route?.arrivalCenterIdentifier == nil)
    #expect(route?.transitionCenterIdentifiers == nil)
    #expect(route?.coordinationRequired == nil)
    #expect(route?.playInfo == nil)
    #expect(route?.navigationEquipment == nil)
    #expect(route?.lengthNM == nil)

    let diagnostics = await parser.takeDiagnostics()
    #expect(diagnostics.count == 1)
    guard case .recordError = diagnostics[0] else {
      Issue.record("expected .recordError")
      return
    }
  }
}
