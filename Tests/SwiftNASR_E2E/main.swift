import Foundation
import Dispatch
import Combine
import SwiftNASR

class E2ETest {
    private var workingURL: URL { URL(fileURLWithPath: FileManager.default.currentDirectoryPath) }
    var distributionURL: URL { workingURL.appendingPathComponent("distribution.zip") }
    
    var nasr: NASR {
        if FileManager.default.fileExists(atPath: distributionURL.path) {
            return NASR.fromLocalArchive(distributionURL)
        } else {
            return NASR.fromInternetToFile(distributionURL)!
        }
    }
    
    let loadingQueue = DispatchQueue(label: "SwiftNASR_E2E.loading", qos: .utility)
    let updatingQueue = DispatchQueue(label: "SwiftNASR_E2E.updating", qos: .userInteractive, attributes: .concurrent)
    var progress = Progress(totalUnitCount: 140)
    var group = DispatchGroup()
    
    func run() {
        group.enter()
        
        test()
        
        group.wait()
    }
    
    func test() {
        preconditionFailure("Must be implemented by subclasses")
    }
    
    func saveData() {
        print("Airports: \(nasr.data.airports!.count)")
        print("ARTCCs: \(nasr.data.ARTCCs!.count)")
        print("FSSes: \(nasr.data.FSSes!.count)")
        
        do {
            let encoder = JSONZipEncoder()
            let data = try encoder.encode(nasr.data)
            
            try data.write(to: workingURL.appendingPathComponent("distribution.json.zip"))
        } catch (let error) {
            fatalError("\(error)")
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class E2ETestWithProgress: E2ETest {
    private var progressCancellable: Cancellable!
    private let monitoringQueue = DispatchQueue(label: "SwiftNASR_E2E.monitoring", qos: .background)
    
    func trackProgress() {
        loadingQueue.async {
            self.progressCancellable = self.monitoringQueue.schedule(after: .init(.now()), interval: 2, tolerance: 1) {
                repeat {
                    sleep(1)
                    let pct = Int((self.progress.fractionCompleted*100).rounded())
                    self.updatingQueue.async { print("\(pct)% \r", terminator: "") }
                } while self.progress.fractionCompleted < 1.0
            }
        }
    }
}

if #available(macOS 12.0, *) {
    AsyncAwaitTest().run()
} else {
    if #available(macOS 10.15, *) {
        CombineTest().run()
    } else {
        CallbacksTest().run()
    }
}
