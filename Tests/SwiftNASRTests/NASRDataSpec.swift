import Foundation
import Nimble
import Quick

@testable import SwiftNASR

class NASRDataSpec: AsyncSpec {
  override class func spec() {
    var parsedData = NASRData()
    var decodedData = NASRData()

    beforeEach {
      let distURL = Bundle.module.resourceURL!.appendingPathComponent(
        "MockDistribution",
        isDirectory: true
      )
      let nasr = NASR.fromLocalDirectory(distURL)

      try await nasr.load()
      try await nasr.parse(
        .states,
        errorHandler: { error in
          fail(error.localizedDescription)
          return false
        }
      )
      try await nasr.parse(
        .airports,
        errorHandler: { _ in
          //                fail(error.localizedDescription)
          return true
        }
      )
      try await nasr.parse(
        .ARTCCFacilities,
        errorHandler: { error in
          fail(error.localizedDescription)
          return false
        }
      )
      try await nasr.parse(
        .flightServiceStations,
        errorHandler: { error in
          fail(error.localizedDescription)
          return false
        }
      )
      try await nasr.parse(
        .navaids,
        errorHandler: { error in
          fail(error.localizedDescription)
          return false
        }
      )

      parsedData = await nasr.data
      let encodedData = try await JSONEncoder().encode(NASRDataCodable(data: parsedData))
      decodedData = try await JSONDecoder().decode(NASRDataCodable.self, from: encodedData)
        .makeData()
    }

    describe("Airport") {
      var parsedSFO: Airport!
      var decodedSFO: Airport!

      beforeEach {
        parsedSFO = await parsedData.airports!.first { $0.LID == "SFO" }!
        decodedSFO = await decodedData.airports!.first { $0.LID == "SFO" }!
      }

      describe("state") {
        it("returns the object") {
          guard let parsedState = await parsedSFO.state,
            let decodedState = await decodedSFO.state
          else {
            fail()
            return
          }
          expect(parsedState.postOfficeCode).to(equal("CA"))
          expect(decodedState.postOfficeCode).to(equal("CA"))
        }
      }

      describe("countyState") {
        it("returns the object") {
          guard let parsedState = await parsedSFO.countyState,
            let decodedState = await decodedSFO.countyState
          else {
            fail()
            return
          }
          expect(parsedState.postOfficeCode).to(equal("CA"))
          expect(decodedState.postOfficeCode).to(equal("CA"))
        }
      }

      describe("boundaryARTCCs") {
        it("returns the object") {
          guard let parsedARTCCs = await parsedSFO.boundaryARTCCs,
            let decodedARTCCs = await decodedSFO.boundaryARTCCs
          else {
            fail()
            return
          }
          expect(parsedARTCCs.count).to(equal(30))
          expect(decodedARTCCs.count).to(equal(30))
        }
      }

      describe("responsibeARTCCs") {
        it("returns the object") {
          guard let parsedARTCCs = await parsedSFO.responsibleARTCCs,
            let decodedARTCCs = await decodedSFO.responsibleARTCCs
          else {
            fail()
            return
          }
          expect(parsedARTCCs.count).to(equal(30))
          expect(decodedARTCCs.count).to(equal(30))
        }
      }

      describe("tieInFSS") {
        it("returns the object") {
          guard let parsedFSS = await parsedSFO.tieInFSS,
            let decodedFSS = await decodedSFO.tieInFSS
          else {
            fail()
            return
          }
          expect(parsedFSS.id).to(equal("OAK"))
          expect(decodedFSS.id).to(equal("OAK"))
        }
      }

      describe("alernateFSS") {
        it("returns the object") {
          let parsedFSS = await parsedSFO.alternateFSS
          let decodedFSS = await decodedSFO.alternateFSS
          expect(parsedFSS).to(beNil())
          expect(decodedFSS).to(beNil())
        }
      }

      describe("NOTAMIssuer") {
        it("returns the object") {
          let parsedIssuer = await parsedSFO.NOTAMIssuer
          let decodedIssuer = await decodedSFO.NOTAMIssuer
          expect(parsedIssuer).to(beNil())
          expect(decodedIssuer).to(beNil())
        }
      }

      describe("RunwayEnd.LAHSO") {
        describe("intersectingRunway") {
          pending("returns the object") {
          }
        }
      }
    }

    describe("ARTCC") {
      var parsedZOA: ARTCC!
      var decodedZOA: ARTCC!

      beforeEach {
        parsedZOA = await parsedData.ARTCCs!.first {
          $0.code == "ZOA" && $0.locationName == "PRIEST" && $0.type == ARTCC.FacilityType.RCAG
        }!
        decodedZOA = await decodedData.ARTCCs!.first {
          $0.code == "ZOA" && $0.locationName == "PRIEST" && $0.type == ARTCC.FacilityType.RCAG
        }!
      }

      describe("state") {
        it("returns the object") {
          guard let parsedState = await parsedZOA.state,
            let decodedState = await decodedZOA.state
          else {
            fail()
            return
          }
          expect(parsedState.postOfficeCode).to(equal("CA"))
          expect(decodedState.postOfficeCode).to(equal("CA"))
        }
      }

      describe("CommFrequency") {
        describe("associatedAirport") {
          it("returns the object") {
            guard
              let parsedFreq = parsedZOA.frequencies.first(where: { $0.frequencyKHz == 134550 }),
              let decodedFreq = decodedZOA.frequencies.first(where: { $0.frequencyKHz == 134550 })
            else {
              fail()
              return
            }
            guard let parsedAirport = await parsedFreq.associatedAirport,
              let decodedAirport = await decodedFreq.associatedAirport
            else {
              fail()
              return
            }
            expect(parsedAirport.LID).to(equal("SFO"))
            expect(decodedAirport.LID).to(equal("SFO"))
          }
        }
      }
    }

    describe("FSS") {
      var parsedOAK: FSS!
      var decodedOAK: FSS!

      beforeEach {
        parsedOAK = await parsedData.FSSes!.first { $0.id == "OAK" }!
        decodedOAK = await decodedData.FSSes!.first { $0.id == "OAK" }!
      }

      describe("nearestFSSWithTeletype") {
        pending("returns the object") {
          guard let parsedFSS = await parsedOAK.nearestFSSWithTeletype,
            let decodedFSS = await decodedOAK.nearestFSSWithTeletype
          else {
            fail()
            return
          }
          expect(parsedFSS.id).to(equal("OAK"))
          expect(decodedFSS.id).to(equal("OAK"))
        }
      }

      describe("state") {
        it("returns the object") {
          guard let parsedState = await parsedOAK.state,
            let decodedState = await decodedOAK.state
          else {
            fail()
            return
          }
          expect(parsedState.postOfficeCode).to(equal("CA"))
          expect(decodedState.postOfficeCode).to(equal("CA"))
        }
      }

      describe("airport") {
        pending("returns the object") {
        }
      }

      describe("CommFacility") {
        describe("state") {
          it("returns the object") {
            guard let parsedState = await parsedOAK.commFacilities[0].state,
              let decodedState = await decodedOAK.commFacilities[0].state
            else {
              fail()
              return
            }
            expect(parsedState.postOfficeCode).to(equal("CA"))
            expect(decodedState.postOfficeCode).to(equal("CA"))
          }
        }
      }
    }

    describe("navaid") {
      var parsedAST: Navaid!

      beforeEach {
        parsedAST = await parsedData.navaids!.first!
      }

      describe("state") {
        it("returns the object") {
          guard let parsedState = await parsedAST.state else {
            fail()
            return
          }
          expect(parsedState.postOfficeCode).to(equal("OR"))
        }
      }

      describe("highAltitudeARTCC") {
        it("returns the object") {
          guard let parsedARTCC = await parsedAST.highAltitudeARTCC else {
            fail()
            return
          }
          expect(parsedARTCC.code).to(equal("ZAN"))
        }
      }

      describe("lowAltitudeARTCC") {
        it("returns the object") {
          guard let parsedARTCC = await parsedAST.lowAltitudeARTCC else {
            fail()
            return
          }
          expect(parsedARTCC.code).to(equal("ZAN"))
        }
      }

      describe("controllingFSS") {
        it("returns the object") {
          guard let parsedFSS = await parsedAST.controllingFSS else {
            fail()
            return
          }
          expect(parsedFSS.id).to(equal("FTW"))
        }
      }
    }
  }
}
