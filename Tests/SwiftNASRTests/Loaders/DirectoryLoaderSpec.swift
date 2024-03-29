import Foundation
import Quick
import Nimble

@testable import SwiftNASR

@available(macOS 10.12, *)
class DirectoryLoaderSpec: QuickSpec {
    override func spec() {
        describe("load") {
            let location = FileManager.default.temporaryDirectory
                .appendingPathComponent(ProcessInfo().globallyUniqueString)
            let loader = DirectoryLoader(location: location)

            it("calls back with the directory") {
                waitUntil { done in
                    loader.load { result in
                        expect({
                            switch result {
                            case let .success(distribution):
                                if (distribution as! DirectoryDistribution).location == location {
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
