import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class DirectoryLoaderSpec: AsyncSpec {
    override class func spec() {
        describe("load") {
            let location = FileManager.default.temporaryDirectory
                .appendingPathComponent(ProcessInfo().globallyUniqueString)
            let loader = DirectoryLoader(location: location)
            
            it("calls back with the directory") {
                let distribution = try await loader.load() as! DirectoryDistribution
                expect(distribution.location).to(equal(location))
            }
        }
    }
}
