import Foundation
import Quick
import Nimble
import ZIPFoundation

@testable import SwiftNASR

@available(macOS 10.12, *)
class ArchiveFileDistributionSpec: QuickSpec {
    private var mockData: Data {
        let data = "Hello, world!\r\nLine 2".data(using: .ascii)!
        let archive = Archive(accessMode: .create)!
        try! archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
            return data.subdata(in: Data.Index(position)..<(Int(position)+size))
        }
        return archive.data!
    }

    override func spec() {
        let tempfile = FileManager.default.temporaryDirectory.appendingPathComponent(ProcessInfo().globallyUniqueString)
        var distribution: ArchiveFileDistribution {
            try! self.mockData.write(to: tempfile)
            return ArchiveFileDistribution(location: tempfile)!
        }

        afterSuite {
            try? FileManager.default.removeItem(at: tempfile)
        }

        describe("readFile") {
            it("reads each line from the file") {
                var count = 0
                var progress = Progress(totalUnitCount: 0)
                
                try! distribution.readFile(path: "APT.TXT", withProgress: { progress = $0 }) { data in
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
                expect { try distribution.readFile(path: "unknown", eachLine: { _ in }) }
                    .to(throwError(Error.noSuchFile(path: "n/a")))
            }
        }
    }
}
