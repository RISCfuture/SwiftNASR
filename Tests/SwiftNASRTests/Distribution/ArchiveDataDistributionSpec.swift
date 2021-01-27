import Foundation
import Quick
import Nimble
import ZIPFoundation

@testable import SwiftNASR

class ArchiveDataDistributionSpec: QuickSpec {
    private var mockData: Data {
        let data = "Hello, world!\r\nLine 2".data(using: .ascii)!
        let archive = Archive(accessMode: .create)!
        try! archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: UInt32(data.count)) { position, size in
            return data.subdata(in: position..<(position+size))
        }
        let cycle = "AIS subscriber files effective date December 3, 2020.".data(using: .ascii)!
        try! archive.addEntry(with: "README.txt", type: .file, uncompressedSize: UInt32(cycle.count)) { position, size in
            return cycle.subdata(in: position..<(position+size))
        }
        return archive.data!
    }

    override func spec() {
        let distribution = ArchiveDataDistribution(data: mockData)!

        describe("readFile") {
            it("reads each line from the file") {
                var count = 0
                try! distribution.readFile(path: "APT.TXT") { data, progress in
                    expect(progress.completedUnitCount).toEventually(equal(21))
                    if count == 0 {
                        expect(data).to(equal("Hello, world!".data(using: .ascii)!))
                    }
                    else if count == 1 {
                        expect(data).to(equal("Line 2".data(using: .ascii)!))
                    }
                    else { fail("too many lines") }

                    count += 1
                }
            }

            it("throws an error if the file doesn't exist") {
                expect { try distribution.readFile(path: "unknown") { _, _ in } }
                    .to(throwError(Error.noSuchFile(path: "n/a")))
            }
        }
        
        describe("readCycle") {
            it("reads the cycle from the README file") {
                try! distribution.readCycle { cycle in
                    expect(cycle!.year).to(equal(2020))
                    expect(cycle!.month).to(equal(12))
                    expect(cycle!.day).to(equal(3))
                }
            }
        }
    }
}
