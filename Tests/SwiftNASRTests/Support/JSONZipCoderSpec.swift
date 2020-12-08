import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class JSONZipCoderSpec: QuickSpec {
    let object = ["foo": 1, "bar": 2]
    let encodedData = "UEsDBBQAAAgIADc8ilFCH1vlEwAAABEAAAARAAAAZGlzdHJpYnV0aW9uLmpzb26rVkpKLFKyMtJRSsvPV7IyrAUAUEsBAhUDFAAACAgANzyKUUIfW+UTAAAAEQAAABEAAAAAAAAAAAAAAKSBAAAAAGRpc3RyaWJ1dGlvbi5qc29uUEsFBgAAAAABAAEAPwAAAEIAAAAAAA=="
    var encoder: JSONZipEncoder {
        let coder = JSONZipEncoder()
        coder.outputFormatting = .sortedKeys
        return coder
    }
    let decoder = JSONZipDecoder()
    
    override func spec() {
        describe("JSONZipEncoder") {
            pending("encodes data") {
                let data = try! self.encoder.encode(self.object)
                expect(data.base64EncodedString()).to(equal(self.encodedData))
            }
        }
        
        describe("JSONZipDecoder") {
            it("decodes data") {
                let data = Data(base64Encoded: self.encodedData)!
                let outObject = try! self.decoder.decode(Dictionary<String, Int>.self, from: data)
                expect(outObject).to(equal(self.object))
            }
        }
    }
}

