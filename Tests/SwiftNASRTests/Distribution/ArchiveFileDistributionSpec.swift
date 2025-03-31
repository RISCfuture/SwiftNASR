import Foundation
import Nimble
import Quick
import ZIPFoundation

@testable import SwiftNASR

class ArchiveFileDistributionSpec: AsyncSpec {
    private static var mockData: Data {
        get throws {
            let data = "Hello, world!\r\nLine 2".data(using: .isoLatin1)!
            let archive = try Archive(accessMode: .create)
            try archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
                return data.subdata(in: Data.Index(position)..<(Int(position) + size))
            }
            return archive.data!
        }
    }

    override class func spec() {
        var distribution: ArchiveFileDistribution!

        aroundEach { test in
            let tempfile = FileManager.default.temporaryDirectory.appendingPathComponent(ProcessInfo().globallyUniqueString)
            try self.mockData.write(to: tempfile)
            distribution = try .init(location: tempfile)

            await test()

            try? FileManager.default.removeItem(at: tempfile)
        }

        describe("readFile") {
            it("reads each line from the file") {
                var iter = 0
                var progress = Progress(totalUnitCount: 0)

                let stream = await distribution.readFile(path: "APT.TXT") { progress = $0 }
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
                    let data = await distribution.readFile(path: "unknown")
                    for try await _ in data {}
                }.to(throwError(Error.noSuchFile(path: "n/a")))
            }
        }
    }
}
