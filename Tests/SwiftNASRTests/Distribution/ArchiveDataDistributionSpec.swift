import Foundation
import Quick
import Nimble
import ZIPFoundation

@testable import SwiftNASR

class ArchiveDataDistributionSpec: QuickSpec {
    private class var mockDataReadmePrefix: Data {
        let data = "Hello, world!\r\nLine 2".data(using: .isoLatin1)!
        let archive = try! Archive(accessMode: .create)
        try! archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
            return data.subdata(in: Data.Index(position)..<(Int(position)+size))
        }
        let cycle = "AIS subscriber files effective date December 3, 2020.".data(using: .isoLatin1)!
        try! archive.addEntry(with: "Read_me_8_Sep_2022.txt", type: .file, uncompressedSize: Int64(cycle.count)) { (position: Int64, size: Int) in
            return cycle.subdata(in: Data.Index(position)..<(Int(position)+size))
        }
        return archive.data!
    }
    
    private class var mockDataReadme: Data {
        let data = "Hello, world!\r\nLine 2".data(using: .isoLatin1)!
        let archive = try! Archive(accessMode: .create)
        try! archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
            return data.subdata(in: Data.Index(position)..<(Int(position)+size))
        }
        let cycle = "AIS subscriber files effective date December 3, 2020.".data(using: .isoLatin1)!
        try! archive.addEntry(with: "README.txt", type: .file, uncompressedSize: Int64(cycle.count)) { (position: Int64, size: Int) in
            return cycle.subdata(in: Data.Index(position)..<(Int(position)+size))
        }
        return archive.data!
    }

    override class func spec() {
        let distributionPrefix = try! ArchiveDataDistribution(data: mockDataReadmePrefix)
        let distributionReadme = try! ArchiveDataDistribution(data: mockDataReadme)

        describe("readFile") {
            it("reads each line from the file") {
                var count = 0
                var progress = Progress(totalUnitCount: 0)
                
                try! distributionReadme.readFile(path: "APT.TXT", withProgress: { progress = $0 }) { data in
                    expect(progress.completedUnitCount).toEventually(equal(21))
                    if count == 0 {
                        expect(data).to(equal("Hello, world!".data(using: .isoLatin1)!))
                    }
                    else if count == 1 {
                        expect(data).to(equal("Line 2".data(using: .isoLatin1)!))
                    }
                    else { fail("too many lines") }

                    count += 1
                }
            }

            it("throws an error if the file doesn't exist") {
                expect { try distributionReadme.readFile(path: "unknown", eachLine: { _ in }) }
                    .to(throwError(Error.noSuchFile(path: "n/a")))
            }
        }
        
        describe("readCycle") {
            it("reads the cycle from the README file") {
                try! distributionReadme.readCycle { cycle in
                    expect(cycle!.year).to(equal(2020))
                    expect(cycle!.month).to(equal(12))
                    expect(cycle!.day).to(equal(3))
                }
            }
            
            it("reads the cycle from the Read_me_* file") {
                try! distributionPrefix.readCycle { cycle in
                    expect(cycle!.year).to(equal(2020))
                    expect(cycle!.month).to(equal(12))
                    expect(cycle!.day).to(equal(3))
                }
            }
        }
    }
}
