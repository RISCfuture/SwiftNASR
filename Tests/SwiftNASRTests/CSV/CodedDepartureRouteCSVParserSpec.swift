import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class CodedDepartureRouteCSVParserSpec: AsyncSpec {
  override class func spec() {
    describe("CSVCodedDepartureRouteParser") {
      var parser: CSVCodedDepartureRouteParser!
      let csvDirectory = Bundle.module.resourceURL!.appendingPathComponent(
        "MockCSVDistribution",
        isDirectory: true
      )

      beforeEach {
        parser = CSVCodedDepartureRouteParser()
        parser.csvDirectory = csvDirectory
      }

      describe("when parsing CSV files") {
        it("parses coded departure routes from CDR.csv") {
          try await parser.parse(data: Data())

          expect(parser.routes.count).to(equal(5))
        }

        it("parses route codes correctly") {
          try await parser.parse(data: Data())

          let route = parser.routes["ORDLAX01"]
          expect(route).toNot(beNil())
          expect(route?.routeCode).to(equal("ORDLAX01"))
          expect(route?.origin).to(equal("KORD"))
          expect(route?.destination).to(equal("KLAX"))
        }

        it("parses departure fix") {
          try await parser.parse(data: Data())

          let route = parser.routes["ORDLAX01"]
          expect(route?.departureFix).to(equal("MZV"))
        }

        it("parses route string") {
          try await parser.parse(data: Data())

          let route = parser.routes["ORDLAX01"]
          expect(route?.routeString).to(equal("KORD MZV LMN J64 CIVET CIVET4 LAX"))
        }

        it("parses ARTCC identifier") {
          try await parser.parse(data: Data())

          let route = parser.routes["ORDLAX01"]
          expect(route?.ARTCCIdentifier).to(equal("KZAU"))
        }

        it("parses multiple routes") {
          try await parser.parse(data: Data())

          // Check a few different routes
          expect(parser.routes["JFKSFO02"]).toNot(beNil())
          expect(parser.routes["JFKSFO02"]?.origin).to(equal("KJFK"))
          expect(parser.routes["JFKSFO02"]?.destination).to(equal("KSFO"))
          expect(parser.routes["JFKSFO02"]?.ARTCCIdentifier).to(equal("KZNY"))

          expect(parser.routes["DENLAX03"]).toNot(beNil())
          expect(parser.routes["DENLAX03"]?.departureFix).to(equal("PUB"))
        }
      }
    }
  }
}
