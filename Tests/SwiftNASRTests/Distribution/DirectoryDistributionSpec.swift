import Foundation
import Quick
import Nimble
import ZIPFoundation

@testable import SwiftNASR

@available(macOS 10.12, *)
class DirectoryDistributionSpec: QuickSpec {
    private static var mockData = "Hello, world!\r\nLine 2".data(using: .isoLatin1)!

    override class func spec() {
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
                var progress = Progress(totalUnitCount: 0)
                
                try! distribution.readFile(path: "APT.TXT", withProgress: { progress = $0 }) { data in
                    if count == 0 {
                        expect(progress.completedUnitCount).toEventually(equal(34))
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
                expect { try distribution.readFile(path: "unknown", eachLine: { _ in }) }
                    .to(throwError(Error.noSuchFile(path: "n/a")))
            }
        }
    }
}
