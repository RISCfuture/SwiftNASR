import Foundation
import ZIPFoundation

/**
 A JSON encoder that compresses its output into a ZIP archive.

 ``JSONZipEncoder`` behaves like `JSONEncoder`, but writes the encoded JSON into
 a ZIP archive (as a single `distribution.json` entry) to reduce the size of
 serialized ``NASRData``. Decode the result with ``JSONZipDecoder``.
 */
public struct JSONZipEncoder: Sendable {

  /// The output formatting applied to the encoded JSON, mirroring
  /// `JSONEncoder/outputFormatting`.
  public var outputFormatting: JSONEncoder.OutputFormatting

  /**
   Creates a new encoder.

   - Parameter outputFormatting: The output formatting applied to the encoded
                                 JSON.
   */

  public init(outputFormatting: JSONEncoder.OutputFormatting = []) {
    self.outputFormatting = outputFormatting
  }

  /**
   Encodes a value as ZIP-compressed JSON.

   - Parameter value: The value to encode.
   - Returns: The compressed archive data.
   - Throws: ``JSONZipError`` if the archive could not be created, or an encoding
             error from the underlying `JSONEncoder`.
   */

  public func encode(_ value: some Encodable) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = outputFormatting
    do {
      let data = try encoder.encode(value)
      let archive = try Archive(accessMode: .create)
      _ = try archive.addEntry(
        with: distributionEntryName,
        type: .file,
        uncompressedSize: Int64(data.count)
      ) { (position: Int64, size: Int) -> Data in
        data.subdata(in: Data.Index(position)..<Int(position) + size)
      }
      guard let zippedData = archive.data else {
        throw JSONZipError.emptyArchive
      }
      return zippedData
    } catch _ as Archive.ArchiveError {
      throw JSONZipError.couldntReadArchive
    }
  }
}

/**
 A JSON decoder that reads ZIP-compressed JSON produced by ``JSONZipEncoder``.
 */
public struct JSONZipDecoder: Sendable {

  /// Creates a new decoder.
  public init() {}

  /**
   Decodes a value from ZIP-compressed JSON.

   - Parameter type: The type to decode.
   - Parameter data: The compressed archive data.
   - Returns: The decoded value.
   - Throws: ``JSONZipError`` if the archive could not be read, or a decoding
             error from the underlying `JSONDecoder`.
   */

  public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
      let archive = try Archive(data: data, accessMode: .read, pathEncoding: .ascii)
      guard let entry = archive[distributionEntryName] else {
        throw JSONZipError.noDistributionFile
      }

      var json = Data(capacity: Int(entry.uncompressedSize))
      _ = try archive.extract(entry) { json.append($0) }

      return try JSONDecoder().decode(type, from: json)
    } catch _ as Archive.ArchiveError {
      throw JSONZipError.couldntReadArchive
    }
  }
}

// The name of the single archive entry that holds the encoded JSON.
private let distributionEntryName = "distribution.json"

enum JSONZipError: Swift.Error {
  case couldntReadArchive
  case emptyArchive
  case noDistributionFile
}
