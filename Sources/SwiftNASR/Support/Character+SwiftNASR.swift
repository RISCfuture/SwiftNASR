import Foundation

extension Character: @retroactive Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    self = try container.decode(String.self).first!
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(String(self))
  }
}
