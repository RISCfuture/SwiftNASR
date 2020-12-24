import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class NASRDataSpec: QuickSpec {
    let fixturesURL = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .appendingPathComponent("Support").appendingPathComponent("Fixtures")
    
    override func spec() {
        let distURL = fixturesURL.appendingPathComponent("MockDistribution")
        let NASR = SwiftNASR.fromLocalDirectory(distURL)
        
        let group = DispatchGroup()
        group.enter()
        NASR.load { _ in group.leave() }
        group.wait()
        
        try! NASR.parse(.states) { _ in false }
        try! NASR.parse(.airports) { _ in false }
        try! NASR.parse(.ARTCCFacilities) { _ in false }
        try! NASR.parse(.flightServiceStations) { _ in false }
        
        let parsedData = NASR.data
        let encodedData = try! JSONEncoder().encode(parsedData)
        let decodedData = try! JSONDecoder().decode(NASRData.self, from: encodedData)
                
        describe("Airport") {
            let parsedSFO = parsedData.airports!.first(where: { $0.LID == "SFO" })!
            let decodedSFO = decodedData.airports!.first(where: { $0.LID == "SFO" })!

            describe("state") {
                it("returns the object") {
                    expect(parsedSFO.state!.postOfficeCode).to(equal("CA"))
                    expect(decodedSFO.state!.postOfficeCode).to(equal("CA"))
                }
            }
            
            describe("countyState") {
                it("returns the object") {
                    expect(parsedSFO.countyState!.postOfficeCode).to(equal("CA"))
                    expect(decodedSFO.countyState!.postOfficeCode).to(equal("CA"))
                }
            }
            
            describe("boundaryARTCCs") {
                it("returns the object") {
                    expect(parsedSFO.boundaryARTCCs!.count).to(equal(30))
                    expect(decodedSFO.boundaryARTCCs!.count).to(equal(30))
                }
            }
            
            describe("responsibeARTCCs") {
                it("returns the object") {
                    expect(parsedSFO.responsibleARTCCs!.count).to(equal(30))
                    expect(decodedSFO.responsibleARTCCs!.count).to(equal(30))
                }
            }
            
            describe("tieInFSS") {
                it("returns the object") {
                    expect(parsedSFO.tieInFSS!.ID).to(equal("OAK"))
                    expect(decodedSFO.tieInFSS!.ID).to(equal("OAK"))
                }
            }
            
            describe("alernateFSS") {
                it("returns the object") {
                    expect(parsedSFO.alternateFSS).to(beNil())
                    expect(decodedSFO.alternateFSS).to(beNil())
                }
            }
            
            describe("NOTAMIssuer") {
                it("returns the object") {
                    expect(parsedSFO.NOTAMIssuer).to(beNil())
                    expect(decodedSFO.NOTAMIssuer).to(beNil())
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
            let parsedZOA = parsedData.ARTCCs!.first(where: { $0.ID == "ZOA" && $0.locationName == "PRIEST" && $0.type == .RCAG })!
            let decodedZOA = decodedData.ARTCCs!.first(where: { $0.ID == "ZOA" && $0.locationName == "PRIEST" && $0.type == .RCAG })!
            
            describe("state") {
                it("returns the object") {
                    expect(parsedZOA.state!.postOfficeCode).to(equal("CA"))
                    expect(decodedZOA.state!.postOfficeCode).to(equal("CA"))
                }
            }
            
            describe("CommFrequency") {
                describe("associatedAirport") {
                    it("returns the object") {
                        let parsedFreq = parsedZOA.frequencies.first(where:  { $0.frequency == 134550 })!
                        expect(parsedFreq.associatedAirport!.LID).to(equal("SFO"))
                        
                        let decodedFreq = decodedZOA.frequencies.first(where:  { $0.frequency == 134550 })!
                        expect(decodedFreq.associatedAirport!.LID).to(equal("SFO"))
                    }
                }
            }
        }
        
        describe("FSS") {
            let parsedOAK = parsedData.FSSes!.first(where: { $0.ID == "OAK" })!
            let decodedOAK = decodedData.FSSes!.first(where: { $0.ID == "OAK" })!
            
            describe("nearestFSSWithTeletype") {
                pending("returns the object") {
                    expect(parsedOAK.nearestFSSWithTeletype!.ID).to(equal("OAK"))
                    expect(decodedOAK.nearestFSSWithTeletype!.ID).to(equal("OAK"))
                }
            }
            
            describe("state") {
                it("returns the object") {
                    expect(parsedOAK.state!.postOfficeCode).to(equal("CA"))
                    expect(decodedOAK.state!.postOfficeCode).to(equal("CA"))
                }
            }
            
            describe("airport") {
                pending("returns the object") {
                }
            }
            
            describe("CommFacility") {
                describe("state") {
                    it("returns the object") {
                        expect(parsedOAK.commFacilities[0].state!.postOfficeCode).to(equal("CA"))
                        expect(decodedOAK.commFacilities[0].state!.postOfficeCode).to(equal("CA"))
                    }
                }
            }
        }
    }
}
