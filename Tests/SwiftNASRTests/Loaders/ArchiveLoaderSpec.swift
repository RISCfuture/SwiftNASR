import Foundation
import Quick
import Nimble
import ZIPFoundation

@testable import SwiftNASR

@available(macOS 10.12, *)
class ArchiveLoaderSpec: QuickSpec {
    private var mockData: Data {
        let data = "Hello, world!".data(using: .ascii)!
        let archive = try! Archive(accessMode: .create)
        try! archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
            return data.subdata(in: Data.Index(position)..<(Int(position)+size))
        }
        return archive.data!
    }

    override func spec() {
        describe("load") {
            let location = FileManager.default.temporaryDirectory
                .appendingPathComponent(ProcessInfo().globallyUniqueString)
            let loader = ArchiveLoader(location: location)

            beforeSuite {
                try! self.mockData.write(to: location)
            }

            afterSuite {
                try? FileManager.default.removeItem(at: location)
            }

            it("calls back with the archive") {
                waitUntil { done in
                    loader.load { result in
                        expect({
                            switch result {
                            case let .success(distribution):
                                if (distribution as! ArchiveFileDistribution).location == location {
                                    return { .succeeded }
                                } else {
                                    return { .failed(reason: "wrong location") }
                                }
                            case let .failure(error):
                                return { .failed(reason: "\(error)") }
                            }
                            }).to(succeed())
                        done()
                    }
                }
            }
        }
    }
}
