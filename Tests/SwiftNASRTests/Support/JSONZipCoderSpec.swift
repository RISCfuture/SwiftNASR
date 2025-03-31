import Foundation
import Nimble
import Quick
import ZIPFoundation

@testable import SwiftNASR

final class JSONZipCoderSpec: QuickSpec {
    override static func spec() {
        let object = ["foo": 1, "bar": 2]
        var encoder: JSONZipEncoder {
            let coder = JSONZipEncoder()
            coder.outputFormatting = .sortedKeys
            return coder
        }
        let decoder = JSONZipDecoder()

        describe("JSONZipEncoder") {
            it("encodes data") {
                let data = try encoder.encode(object)
                let archive = try Archive(data: data, accessMode: .read, pathEncoding: .ascii)
                guard let entry = archive["distribution.json"] else {
                    fail("Expected archive to contain distribution.json")
                    return
                }
                expect(entry.uncompressedSize).to(equal(17))
            }
        }

        describe("JSONZipDecoder") {
            it("decodes data") {
                let encodedData = "UEsDBBQAAAgAAGKhf1pCH1vlEQAAABEAAAARAAAAZGlzdHJpYnV0aW9uLmpzb257ImJhciI6MiwiZm9vIjoxfVBLAQIVAxQAAAgAAGKhf1pCH1vlEQAAABEAAAARAAAAAAAAAAAAAACkgQAAAABkaXN0cmlidXRpb24uanNvblBLBQYAAAAAAQABAD8AAABAAAAAAAA="
                let data = Data(base64Encoded: encodedData)!
                let outObject = try decoder.decode(Dictionary<String, Int>.self, from: data)
                expect(outObject).to(equal(object))
            }
        }
    }
}
