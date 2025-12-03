import Foundation
import Nimble
import Quick

@testable import SwiftNASR

final class AttendanceScheduleSpec: QuickSpec {
  override static func spec() {
    var encoder: JSONEncoder {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .sortedKeys
      return encoder
    }
    let decoder = JSONDecoder()

    describe("encode") {
      it("encodes a .components instance") {
        let schedule: AttendanceSchedule = .components(monthly: "1", daily: "2", hourly: "3")
        let encoded = String(data: try encoder.encode(schedule), encoding: .utf8)
        expect(encoded).to(equal(#"{"daily":"2","hourly":"3","monthly":"1","type":"components"}"#))
      }

      it("encodes a .custom instance") {
        let schedule: AttendanceSchedule = .custom("hello world")
        let encoded = String(data: try encoder.encode(schedule), encoding: .utf8)
        expect(encoded).to(equal(#"{"schedule":"hello world","type":"custom"}"#))
      }
    }

    describe("decode") {
      it("decodes a .components instance") {
        let encoded = Data(#"{"daily":"2","hourly":"3","monthly":"1","type":"components"}"#.utf8)
        let schedule = try decoder.decode(AttendanceSchedule.self, from: encoded)

        guard case .components(let monthly, let daily, let hourly) = schedule else {
          fail("Expected AttendanceSchedule.components, got .custom")
          return
        }
        expect(monthly).to(equal("1"))
        expect(daily).to(equal("2"))
        expect(hourly).to(equal("3"))
      }

      it("decodes a .custom instance") {
        let encoded = Data(#"{"schedule":"hello world","type":"custom"}"#.utf8)
        let schedule = try decoder.decode(AttendanceSchedule.self, from: encoded)

        guard case .custom(let value) = schedule else {
          fail("Expected AttendanceSchedule.custom, got .components")
          return
        }
        expect(value).to(equal("hello world"))
      }
    }
  }
}
