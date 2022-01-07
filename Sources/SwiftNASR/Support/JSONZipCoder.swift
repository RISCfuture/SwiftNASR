import Foundation
import ZIPFoundation

public class JSONZipEncoder: JSONEncoder {
    public override func encode<T>(_ value: T) throws -> Data where T : Encodable {
        let data = try super.encode(value)
        guard let archive = Archive(accessMode: .create) else {
            throw JSONZipError.couldntCreateArchive
        }
        _ = try archive.addEntry(with: "distribution.json", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) -> Data in
            data.subdata(in: Data.Index(position)..<Int(position)+size)
        }
        guard let zippedData = archive.data else {
            throw JSONZipError.emptyArchive
        }
        return zippedData
    }
}

public class JSONZipDecoder: JSONDecoder {
    public override func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        guard let archive = Archive(data: data, accessMode: .read, preferredEncoding: .ascii) else {
            throw JSONZipError.couldntReadArchive
        }
        guard let entry = archive["distribution.json"] else {
            throw JSONZipError.noDistributionFile
        }

        var json = Data(capacity: Int(entry.uncompressedSize))
        _ = try archive.extract(entry) { json.append($0) }

        return try super.decode(type, from: json)
    }
}

enum JSONZipError: Swift.Error {
    case couldntCreateArchive
    case couldntReadArchive
    case emptyArchive
    case noDistributionFile
}
