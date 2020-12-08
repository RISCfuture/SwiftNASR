/// A schedule that an airport or other facility can be attended during.
public enum AttendanceSchedule: Codable {
    
    /// An attendance schedule consisting of monthly, daily, and hourly
    /// components.
    case components(monthly: String, daily: String, hourly: String)
    
    /// An attendance schedule written as freeform text.
    case custom(_ schedule: String)
            
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let type = Kinds(rawValue: try container.decode(String.self, forKey: .type)) else {
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.type, in: container, debugDescription: "invalid enum value")
        }
        switch type {
            case .components:
                let monthly = try container.decode(String.self, forKey: .monthly)
                let daily = try container.decode(String.self, forKey: .daily)
                let hourly = try container.decode(String.self, forKey: .hourly)
                self = .components(monthly: monthly, daily: daily, hourly: hourly)
            case .custom:
                let schedule = try container.decode(String.self, forKey: .schedule)
                self = .custom(schedule)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
            case .components(let monthly, let daily, let hourly):
                try container.encode(Kinds.components.rawValue, forKey: .type)
                try container.encode(monthly, forKey: .monthly)
                try container.encode(daily, forKey: .daily)
                try container.encode(hourly, forKey: .hourly)
            case .custom(let schedule):
                try container.encode(Kinds.custom.rawValue, forKey: .type)
                try container.encode(schedule, forKey: .schedule)
        }
    }
    
    private enum Kinds: String {
        case components, custom
    }
    
    private enum CodingKeys: CodingKey {
        case type, monthly, daily, hourly, schedule
    }
}
