import Foundation
import Nimble
import Quick
import ZIPFoundation

@testable import SwiftNASR

class ArchiveDataDistributionSpec: AsyncSpec {
    private static var mockDataReadmePrefix: Data {
        get throws {
            let data = "Hello, world!\r\nLine 2".data(using: .isoLatin1)!
            let archive = try Archive(accessMode: .create)
            try archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
                return data.subdata(in: Data.Index(position)..<(Int(position) + size))
            }
            let cycle = "AIS subscriber files effective date December 3, 2020.".data(using: .isoLatin1)!
            try archive.addEntry(with: "Read_me_8_Sep_2022.txt", type: .file, uncompressedSize: Int64(cycle.count)) { (position: Int64, size: Int) in
                return cycle.subdata(in: Data.Index(position)..<(Int(position) + size))
            }
            return archive.data!
        }
    }

    private static var mockDataReadme: Data {
        get throws {
            let data = "Hello, world!\r\nLine 2".data(using: .isoLatin1)!
            let archive = try Archive(accessMode: .create)
            try archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
                return data.subdata(in: Data.Index(position)..<(Int(position) + size))
            }
            let cycle = "AIS subscriber files effective date December 3, 2020.".data(using: .isoLatin1)!
            try archive.addEntry(with: "README.txt", type: .file, uncompressedSize: Int64(cycle.count)) { (position: Int64, size: Int) in
                return cycle.subdata(in: Data.Index(position)..<(Int(position) + size))
            }
            return archive.data!
        }
    }

    override class func spec() {
//        let distributionPrefix = try ArchiveDataDistribution(data: mockDataReadmePrefix)
        var distributionReadme: ArchiveDataDistribution!

        beforeEach {
            distributionReadme = try .init(data: mockDataReadme)
        }

        describe("readFile") {
            it("reads each line from the file") {
                var iter = 0
                var progress = Progress(totalUnitCount: 0)

                let stream = await distributionReadme.readFile(path: "APT.TXT") { progress = $0 }
                await expect(progress.completedUnitCount).toEventually(equal(21))

                for try await data in stream {
                    if iter == 0 {
                        expect(data).to(equal("Hello, world!".data(using: .isoLatin1)!))
                    }
                    else if iter == 1 {
                        expect(data).to(equal("Line 2".data(using: .isoLatin1)!))
                    }
                    else { fail("too many lines") }

                    iter += 1
                }
            }

            it("throws an error if the file doesn't exist") {
                await expect {
                    let stream = await distributionReadme.readFile(path: "unknown")
                    for try await foo in stream { print(foo) }
                }
                    .to(throwError(Error.noSuchFile(path: "n/a")))
            }
        }

        describe("readCycle") {
            it("reads the cycle from the README file") {
                guard let cycle = try await distributionReadme.readCycle() else { fail(); return }
                expect(cycle.year).to(equal(2020))
                expect(cycle.month).to(equal(12))
                expect(cycle.day).to(equal(3))
            }

            it("reads the cycle from the Read_me_* file") {
                guard let cycle = try await distributionReadme.readCycle() else { fail(); return }
                expect(cycle.year).to(equal(2020))
                expect(cycle.month).to(equal(12))
                expect(cycle.day).to(equal(3))
            }
        }
    }
}
