import Foundation

protocol RecordEnum: RawRepresentable where RawValue: Hashable {
    static var synonyms: Dictionary<RawValue, Self> { get }
    
    static func `for`(_ raw: RawValue) -> Self?
}

extension RecordEnum {
    static var synonyms: Dictionary<RawValue, Self> { [:] }
    
    static func `for`(_ raw: RawValue) -> Self? {
        if let val = Self(rawValue: raw) { return val }
        if let synVal = synonyms[raw] { return synVal }
        return nil
    }
}
