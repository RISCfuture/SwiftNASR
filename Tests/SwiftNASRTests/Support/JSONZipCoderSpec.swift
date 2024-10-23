import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class JSONZipCoderSpec: QuickSpec {
    override class func spec() {
        let object = ["foo": 1, "bar": 2]
        let encodedData = "UEsDBBQAAAgIADc8ilFCH1vlEwAAABEAAAARAAAAZGlzdHJpYnV0aW9uLmpzb26rVkpKLFKyMtJRSsvPV7IyrAUAUEsBAhUDFAAACAgANzyKUUIfW+UTAAAAEQAAABEAAAAAAAAAAAAAAKSBAAAAAGRpc3RyaWJ1dGlvbi5qc29uUEsFBgAAAAABAAEAPwAAAEIAAAAAAA=="
        var encoder: JSONZipEncoder {
            let coder = JSONZipEncoder()
            coder.outputFormatting = .sortedKeys
            return coder
        }
        let decoder = JSONZipDecoder()

        describe("JSONZipEncoder") {
            pending("encodes data") {
                let data = try encoder.encode(object)
                expect(data.base64EncodedString()).to(equal(encodedData))
            }
        }
        
        describe("JSONZipDecoder") {
            it("decodes data") {
                let data = Data(base64Encoded: encodedData)!
                let outObject = try decoder.decode(Dictionary<String, Int>.self, from: data)
                expect(outObject).to(equal(object))
            }
        }
    }
}

