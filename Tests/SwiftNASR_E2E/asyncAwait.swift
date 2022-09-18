import Foundation
import SwiftNASR

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
class AsyncAwaitTest: E2ETest {
    override func test() {
        Task.detached(priority: .high) { await self.testWithAsyncAwait() }
    }
    
    private func testWithAsyncAwait() async {
        print("Loading…")
        let _ = try! await nasr.load(progress: &progress)
        
        async let airports = try! nasr.parseAirports() { error in
            print(error)
            return true
        }
        
        async let artccs = try! nasr.parseARTCCs() { error in
            print(error)
            return true
        }
        
        async let fsses = try! nasr.parseFSSes() { error in
            print(error)
            return true
        }
        
        let _ = await [airports, artccs, fsses] as [Any]
        
        print("Saving…")
        saveData()
        
        group.leave()
    }
}
