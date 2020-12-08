/**
 This class contains the remarks applied to a NASR record. Remarks are written
 either by the FAA officials managing the data or the person submitting the data
 to the FAA. Remarks can be applied to a record as a whole, or to a specific
 field within the record.
 
 The `RemarkField` type will be a Codable enum representing all the fields in
 a record type that can have a remark applied to them.
 */

public struct Remarks<RemarkField>: Codable where RemarkField: Codable & Equatable {
    
    /// Remarks applied to a record as a whole.
    public var general = Array<String>()
    
    var fieldRemarks = Array<Remark<RemarkField>>()
    
    
    /**
     Gets the remarks for a specific field.
     
     - Parameter field: The field to get remarks for.
     - Returns: The remarks for that field (if any).
     */
    public func forField(_ field: RemarkField) -> Array<String> {
        return fieldRemarks.filter { $0.field == field }.map { $0.remark }
    }
    
    mutating func append(remark: String, forField field: RemarkField) {
        fieldRemarks.append(Remark(field: field, remark: remark))
    }
}

struct Remark<RemarkField>: Codable where RemarkField: Codable {
    public let field: RemarkField
    public let remark: String
}
