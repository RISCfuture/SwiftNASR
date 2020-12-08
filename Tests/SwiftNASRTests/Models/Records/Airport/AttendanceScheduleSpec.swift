import Foundation
import Quick
import Nimble

@testable import SwiftNASR

class AttendanceScheduleSpec: QuickSpec {
    override func spec() {
        var encoder: JSONEncoder {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return encoder
        }
        let decoder = JSONDecoder()
        
        describe("encode") {
            it("encodes a .components instance") {
                let schedule: AttendanceSchedule = .components(monthly: "1", daily: "2", hourly: "3")
                let encoded = String(data: try! encoder.encode(schedule), encoding: .utf8)
                expect(encoded).to(equal(#"{"daily":"2","hourly":"3","monthly":"1","type":"components"}"#))
            }
            
            it("encodes a .custom instance") {
                let schedule: AttendanceSchedule = .custom("hello world")
                let encoded = String(data: try! encoder.encode(schedule), encoding: .utf8)
                expect(encoded).to(equal(#"{"schedule":"hello world","type":"custom"}"#))
            }
        }
        
        describe("decode") {
            it("decodes a .components instance") {
                let encoded = #"{"daily":"2","hourly":"3","monthly":"1","type":"components"}"#.data(using: .utf8)!
                let schedule = try! decoder.decode(AttendanceSchedule.self, from: encoded)
                
                switch schedule {
                    case .components(let monthly, let daily, let hourly):
                        expect(monthly).to(equal("1"))
                        expect(daily).to(equal("2"))
                        expect(hourly).to(equal("3"))
                    case .custom(_):
                        fail("Expected AttendanceSchedule.components, got .custom")
                }
            }
            
            it("decodes a .custom instance") {
                let encoded = #"{"schedule":"hello world","type":"custom"}"#.data(using: .utf8)!
                let schedule = try! decoder.decode(AttendanceSchedule.self, from: encoded)
                
                switch schedule {
                    case .components(_, _, _):
                        fail("Expected AttendanceSchedule.custom, got .components")
                    case .custom(let value):
                        expect(value).to(equal("hello world"))
                }
            }
        }
    }
}
