import Foundation
import Quick
import Nimble
import ZIPFoundation

@testable import SwiftNASR

class ArchiveLoaderSpec: AsyncSpec {
    private class var mockData: Data {
        let data = "Hello, world!".data(using: .isoLatin1)!
        let archive = try! Archive(accessMode: .create)
        try! archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
            return data.subdata(in: Data.Index(position)..<(Int(position)+size))
        }
        return archive.data!
    }

    override static func spec() {
        describe("load") {
            let location = FileManager.default.temporaryDirectory
                .appendingPathComponent(ProcessInfo().globallyUniqueString)
            let loader = ArchiveLoader(location: location)

            beforeSuite {
                try self.mockData.write(to: location)
            }

            afterSuite {
                try? FileManager.default.removeItem(at: location)
            }

            it("calls back with the archive") {
                let distribution = try await loader.load() as! ArchiveFileDistribution
                expect(distribution.location).to(equal(location))
            }
        }
    }
}
