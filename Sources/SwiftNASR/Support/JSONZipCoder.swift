import Foundation
import ZIPFoundation

public class JSONZipEncoder: JSONEncoder, @unchecked Sendable {
  override public func encode<T>(_ value: T) throws -> Data where T: Encodable {
    do {
      let data = try super.encode(value)
      let archive = try Archive(accessMode: .create)
      _ = try archive.addEntry(
        with: "distribution.json",
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

public class JSONZipDecoder: JSONDecoder, @unchecked Sendable {
  override public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
    do {
      let archive = try Archive(data: data, accessMode: .read, pathEncoding: .ascii)
      guard let entry = archive["distribution.json"] else {
        throw JSONZipError.noDistributionFile
      }

      var json = Data(capacity: Int(entry.uncompressedSize))
      _ = try archive.extract(entry) { json.append($0) }

      return try super.decode(type, from: json)
    } catch _ as Archive.ArchiveError {
      throw JSONZipError.couldntReadArchive
    }
  }
}

enum JSONZipError: Swift.Error {
  case couldntCreateArchive
  case couldntReadArchive
  case emptyArchive
  case noDistributionFile
}
