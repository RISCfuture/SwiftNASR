import Foundation
import Quick
import Nimble
import ZIPFoundation

@testable import SwiftNASR

@available(OSX 10.12, *)
class ArchiveLoaderSpec: QuickSpec {
    private var mockData: Data {
        let data = "Hello, world!".data(using: .ascii)!
        let archive = Archive(accessMode: .create)!
        try! archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: UInt32(data.count)) { position, size in
            return data.subdata(in: position..<(position+size))
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
                    _ = loader.load { result in
                        expect({
                            switch result {
                            case .success(let distribution):
                                if (distribution as! ArchiveFileDistribution).location == location {
                                    return { .succeeded }
                                } else {
                                    return { .failed(reason: "wrong location") }
                                }
                            case .failure(let error):
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
