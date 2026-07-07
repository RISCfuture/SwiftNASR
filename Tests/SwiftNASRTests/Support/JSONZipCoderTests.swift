import Foundation
import Testing
import ZIPFoundation

@testable import SwiftNASR

@Suite
struct JSONZipCoderTests {
  private let object = ["foo": 1, "bar": 2]
  private let encoder = JSONZipEncoder(outputFormatting: .sortedKeys)
  private let decoder = JSONZipDecoder()

  @Test
  func encodesData() throws {
    let data = try encoder.encode(object)
    let archive = try Archive(data: data, accessMode: .read, pathEncoding: .ascii)
    let entry = try #require(
      archive["distribution.json"],
      "Expected archive to contain distribution.json"
    )
    #expect(entry.uncompressedSize == 17)
  }

  @Test
  func decodesData() throws {
    let encodedData =
      "UEsDBBQAAAgAAGKhf1pCH1vlEQAAABEAAAARAAAAZGlzdHJpYnV0aW9uLmpzb257ImJhciI6MiwiZm9vIjoxfVBLAQIVAxQAAAgAAGKhf1pCH1vlEQAAABEAAAARAAAAAAAAAAAAAACkgQAAAABkaXN0cmlidXRpb24uanNvblBLBQYAAAAAAQABAD8AAABAAAAAAAA="
    let data = Data(base64Encoded: encodedData)!
    let outObject = try decoder.decode(Dictionary<String, Int>.self, from: data)
    #expect(outObject == object)
  }
}
