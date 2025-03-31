import Foundation

protocol FixedWidthNoRecordIDParser: LayoutDataParser {
    func parseValues(_ values: [String]) throws
    func formatForData(_ data: Data) throws -> NASRTable
}

extension FixedWidthNoRecordIDParser {
    func parse(data: Data) throws {
        let values = try formatForData(data).fields.map { field in
            return String(data: data[field.range], encoding: .isoLatin1)!
        }

        try parseValues(values)
    }

    @available(*, unavailable)
    func finish(data _: NASRData) {
        fatalError("must be implemented by subclasses")
    }
}
