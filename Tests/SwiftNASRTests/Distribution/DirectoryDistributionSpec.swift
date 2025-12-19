import Foundation
import Nimble
import Quick
import ZIPFoundation

@testable import SwiftNASR

class DirectoryDistributionSpec: AsyncSpec {
  override class func spec() {
    var distribution: DirectoryDistribution!

    aroundEach { test in
      let mockData = "Hello, world!\r\nLine 2".data(using: .isoLatin1)!
      let tempdir = FileManager.default.temporaryDirectory.appendingPathComponent(
        ProcessInfo().globallyUniqueString
      )
      try FileManager.default.createDirectory(at: tempdir, withIntermediateDirectories: true)
      try mockData.write(to: tempdir.appendingPathComponent("APT.txt"))

      try FileManager.default.createDirectory(at: tempdir, withIntermediateDirectories: true)
      try mockData.write(to: tempdir.appendingPathComponent("APT.txt"))
      distribution = DirectoryDistribution(location: tempdir)

      await test()

      try? FileManager.default.removeItem(at: tempdir)
    }

    describe("readFile") {
      it("reads each line from the file") {
        var iter = 0
        var progress = Progress(totalUnitCount: 0)

        let stream = await distribution.readFile(path: "APT.TXT") { progress = $0 }

        for try await data in stream {
          if iter == 0 {
            await expect(progress.completedUnitCount).toEventually(equal(35))
            expect(data).to(equal("Hello, world!".data(using: .isoLatin1)!))
          } else if iter == 1 {
            expect(data).to(equal("Line 2".data(using: .isoLatin1)!))
          } else {
            fail("too many lines")
          }

          iter += 1
        }
      }

      it("throws an error if the file doesn't exist") {
        await expect {
          let stream = await distribution.readFile(path: "unknown")
          for try await _ in stream {}
        }.to(throwError(Error.noSuchFile(path: "n/a")))
      }
    }
  }
}
