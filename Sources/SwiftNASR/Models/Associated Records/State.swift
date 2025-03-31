/**
 A state, territory, APO designation, or FPO designation in the United States,
 or `INTERNATIONAL` for non-US locations.
 */

public struct State: ParentRecord {
    public var id: String { postOfficeCode }

    /// The state or territory name.
    public let name: String

    /// The USPS state or territory code.
    public let postOfficeCode: String

    init(name: String, code: String) {
        self.name = name
        self.postOfficeCode = code
    }

    enum CodingKeys: String, CodingKey {
        case name, postOfficeCode
    }
}
