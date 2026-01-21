import Foundation

protocol FixedWidthNoRecordIDParser: LayoutDataParser {
  func parseValues(_ values: [ArraySlice<UInt8>]) throws
  func formatForData(_ data: Data) throws -> NASRTable
}

extension FixedWidthNoRecordIDParser {
  func parse(data: Data) throws {
    let bytes = [UInt8](data)
    let format = try formatForData(data)
    let slices = format.fields.map { field in
      bytes[Int(field.range.lowerBound)..<Int(field.range.upperBound)]
    }

    try parseValues(slices)
  }

  @available(*, unavailable)
  func finish(data _: NASRData) {
    fatalError("must be implemented by subclasses")
  }
}
