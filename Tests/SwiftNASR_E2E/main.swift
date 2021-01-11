import Foundation
import Dispatch
import SwiftNASR
import Darwin
import Combine

let workingURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let distributionURL = workingURL.appendingPathComponent("distribution.zip")

let nasr: NASR
if FileManager.default.fileExists(atPath: distributionURL.path) {
    nasr = NASR.fromLocalArchive(distributionURL)
} else {
    nasr = NASR.fromInternetToFile(distributionURL)!
}

let loadingQueue = DispatchQueue(label: "SwiftNASR_E2E.loading", qos: .utility)
let monitoringQueue = DispatchQueue(label: "SwiftNASR_E2E.monitoring", qos: .background)
let updatingQueue = DispatchQueue(label: "SwiftNASR_E2E.updating", qos: .userInteractive, attributes: .concurrent)
let progress = Progress(totalUnitCount: 140)

let group = DispatchGroup()
group.enter()

if #available(OSX 10.15, *) {
    let cancellable = monitoringQueue.schedule(after: .init(.now()), interval: 2, tolerance: 1) {
        repeat {
            sleep(1)
            let pct = Int((progress.fractionCompleted*100).rounded())
            updatingQueue.async { print("\(pct)% \r", terminator: "") }
        } while progress.fractionCompleted < 1.0
    }
    print(cancellable)
}

print("Loading...")

@available(OSX 10.15, *)
func testWithCombine() {
    loadingQueue.async {
        let cancellable = nasr.load().map {
            return Publishers.CombineLatest3(
                $0.parseAirports(errorHandler: { print($0) }),
                $0.parseARTCCs(errorHandler: { print($0) }),
                $0.parseFSSes(errorHandler: { print($0) })
            )
        }.switchToLatest()
        .mapError { (error: Swift.Error) -> Swift.Error in print(error); return error }
        .sink(receiveCompletion: { completion in
            do {
                let encoder = JSONZipEncoder()
                let data = try encoder.encode(nasr.data)
                
                try data.write(to: workingURL.appendingPathComponent("distribution.json.zip"))
                group.leave()
            } catch (let error) {
                fatalError("\(error)")
            }
        }, receiveValue: { (airports, ARTCCs, FSSes) in
            updatingQueue.async { print(airports.count, ARTCCs.count, FSSes.count) }
        })
        print(cancellable)
    }
}

func testWithCallbacks() {
    loadingQueue.async {
        let addProgress: (Progress, Int64, inout Bool) -> Void = { newProgress, weight, added in
            if added { return }
            updatingQueue.async { progress.addChild(newProgress, withPendingUnitCount: weight) }
            added = true
        }
        
        let loadProgress = nasr.load { result in
            switch result {
                case .success:
                    print("Parsing airports...")
                    var airportsAdded = false
                    try! nasr.parse(.airports, progressHandler: { addProgress($0, 100, &airportsAdded) }, errorHandler: { error in
                        fputs("\(error)\n", stderr)
                        return true
                    })
                    
                    print("Parsing ARTCCs...")
                    var ARTCCsAdded = false
                    try! nasr.parse(.ARTCCFacilities, progressHandler: { addProgress($0, 20, &ARTCCsAdded) }, errorHandler: { error in
                        fputs("\(error)\n", stderr)
                        return true
                    })

                    print("Parsing FSSes...")
                    var FSSesAdded = false
                    try! nasr.parse(.flightServiceStations, progressHandler: { addProgress($0, 10, &FSSesAdded) }, errorHandler: { error in
                        fputs("\(error)\n", stderr)
                        return true
                    })
                    
                    do {
                        print("Saving...")
                        let encoder = JSONZipEncoder()
                        let data = try encoder.encode(nasr.data)
                        
                        try data.write(to: workingURL.appendingPathComponent("distribution.json.zip"))
                        group.leave()
                    } catch (let error) {
                        fatalError("\(error)")
                    }
                    
                case .failure(let error):
                    fatalError("\(error)")
            }
        }
        progress.addChild(loadProgress, withPendingUnitCount: 10)
    }
}

if #available(OSX 10.15, *) {
    loadingQueue.async { testWithCombine() }
} else {
    loadingQueue.async { testWithCallbacks() }
}

group.wait()
