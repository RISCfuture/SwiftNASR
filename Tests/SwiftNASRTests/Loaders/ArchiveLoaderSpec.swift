import Foundation
import Nimble
import Quick
import ZIPFoundation

@testable import SwiftNASR

class ArchiveLoaderSpec: AsyncSpec {
    private static var mockData: Data {
        get throws {
            let data = "Hello, world!".data(using: .isoLatin1)!
            let archive = try Archive(accessMode: .create)
            try archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
                return data.subdata(in: Data.Index(position)..<(Int(position) + size))
            }
            return archive.data!
        }
    }

    override static func spec() {
        let location = FileManager.default.temporaryDirectory.appendingPathComponent(ProcessInfo().globallyUniqueString)
        var loader: ArchiveLoader!

        describe("load") {
            aroundEach { test in
                try self.mockData.write(to: location)
                loader = ArchiveLoader(location: location)

                await test()
                try FileManager.default.removeItem(at: location)
            }

            it("calls back with the archive") {
                let distribution = try loader.load() as! ArchiveFileDistribution
                expect(distribution.location).to(equal(location))
            }
        }
    }
}
