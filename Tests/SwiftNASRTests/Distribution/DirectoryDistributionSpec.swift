import Foundation
import Quick
import Nimble
import ZIPFoundation

@testable import SwiftNASR

@available(macOS 10.12, *)
class DirectoryDistributionSpec: QuickSpec {
    private var mockData = "Hello, world!\r\nLine 2".data(using: .ascii)!

    override func spec() {
        let tempdir = FileManager.default.temporaryDirectory.appendingPathComponent(ProcessInfo().globallyUniqueString)
        var distribution: DirectoryDistribution {
            try! FileManager.default.createDirectory(at: tempdir, withIntermediateDirectories: true)
            try! self.mockData.write(to: tempdir.appendingPathComponent("APT.txt"))
            return DirectoryDistribution(location: tempdir)
        }

        afterSuite {
            try? FileManager.default.removeItem(at: tempdir)
        }

        describe("readFile") {
            it("reads each line from the file") {
                var count = 0
                try! distribution.readFile(path: "APT.TXT") { data, progress in
                    if count == 0 {
                        expect(progress.completedUnitCount).toEventually(equal(34))
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
    }
}
