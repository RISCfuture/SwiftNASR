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
        return archive.data!
    }

    override func spec() {
        let distribution = ArchiveDataDistribution(data: mockData)!

        describe("readFile") {
            it("reads each line from the file") {
                var count = 0
                try! distribution.readFile(path: "APT.TXT") { data in
                    if count == 0 { expect(data).to(equal("Hello, world!".data(using: .ascii)!)) }
                    else if count == 1 { expect(data).to(equal("Line 2".data(using: .ascii)!)) }
                    else { fail("too many lines") }

                    count += 1
                }
            }

            it("throws an error if the file doesn't exist") {
                expect { try distribution.readFile(path: "unknown") { _ in } }
                    .to(throwError(DistributionError.noSuchFile(path: "n/a")))
            }
        }
    }
}
