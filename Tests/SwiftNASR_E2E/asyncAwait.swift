import Foundation
import SwiftNASR

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
class AsyncAwaitTest: E2ETestWithProgress {
    override func test() {
        Task(priority: .high) { await self.testWithAsyncAwait() }
    }
    
    private func testWithAsyncAwait() async {
        print("Loading…")
        let _ = try! await nasr.load(withProgress: { self.progress.addChild($0, withPendingUnitCount: 1)})
        print("Done loading; parsing…")
        
        async let airports = try! nasr.parseAirports(withProgress: { self.progress.addChild($0, withPendingUnitCount: 89) }) { error in
            print(error)
            return true
        }
        
        async let artccs = try! nasr.parseARTCCs(withProgress: { self.progress.addChild($0, withPendingUnitCount: 5) }) { error in
            print(error)
            return true
        }
        
        async let fsses = try! nasr.parseFSSes(withProgress: { self.progress.addChild($0, withPendingUnitCount: 5) }) { error in
            print(error)
            return true
        }
        
        let _ = await [airports, artccs, fsses] as [Any]
        
        print("Saving…")
        saveData()
        
        group.leave()
    }
}
