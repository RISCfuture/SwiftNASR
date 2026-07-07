import Foundation
import Testing

@testable import SwiftNASR

@Suite
struct AttendanceScheduleTests {
  private var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return encoder
  }
  private let decoder = JSONDecoder()

  // MARK: encode

  @Test
  func encodesAComponentsInstance() throws {
    let schedule: AttendanceSchedule = .components(monthly: "1", daily: "2", hourly: "3")
    let encoded = String(data: try encoder.encode(schedule), encoding: .utf8)
    #expect(encoded == #"{"daily":"2","hourly":"3","monthly":"1","type":"components"}"#)
  }

  @Test
  func encodesACustomInstance() throws {
    let schedule: AttendanceSchedule = .custom("hello world")
    let encoded = String(data: try encoder.encode(schedule), encoding: .utf8)
    #expect(encoded == #"{"schedule":"hello world","type":"custom"}"#)
  }

  // MARK: decode

  @Test
  func decodesAComponentsInstance() throws {
    let encoded = Data(#"{"daily":"2","hourly":"3","monthly":"1","type":"components"}"#.utf8)
    let schedule = try decoder.decode(AttendanceSchedule.self, from: encoded)

    guard case let .components(monthly, daily, hourly) = schedule else {
      Issue.record("Expected AttendanceSchedule.components, got .custom")
      return
    }
    #expect(monthly == "1")
    #expect(daily == "2")
    #expect(hourly == "3")
  }

  @Test
  func decodesACustomInstance() throws {
    let encoded = Data(#"{"schedule":"hello world","type":"custom"}"#.utf8)
    let schedule = try decoder.decode(AttendanceSchedule.self, from: encoded)

    guard case let .custom(value) = schedule else {
      Issue.record("Expected AttendanceSchedule.custom, got .components")
      return
    }
    #expect(value == "hello world")
  }
}
