import Foundation
import Quick
import Nimble

@testable import SwiftNASR

@available(macOS 10.12, *)
class DirectoryLoaderSpec: QuickSpec {
    override class func spec() {
        describe("load") {
            let location = FileManager.default.temporaryDirectory
                .appendingPathComponent(ProcessInfo().globallyUniqueString)
            let loader = DirectoryLoader(location: location)

            it("calls back with the directory") {
                waitUntil { done in
                    loader.load { result in
                        expect(result).to(beSuccess { distribution in
                            expect((distribution as! DirectoryDistribution).location).to(equal(location))
                        })
                        done()
                    }
                }
            }
        }
    }
}
