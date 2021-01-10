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

print("Loading...")

@available(OSX 10.15, *)
func testWithCombine() {
    let group = DispatchGroup()
    group.enter()
    
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
        print(airports.count, ARTCCs.count, FSSes.count)
    })
    group.wait()
    print(cancellable)
}

func testWithCallbacks() {
    let group = DispatchGroup()
    group.enter()
    
    let progress = Progress(totalUnitCount: 140)
    DispatchQueue.global(qos: .background).async {
        repeat {
            sleep(1)
            let pct = Int((progress.fractionCompleted*100).rounded())
            print("\(pct)% \r", terminator: "")
        } while progress.fractionCompleted < 1.0
    }

    let addProgress: (Progress, Int64, inout Bool) -> Void = { newProgress, weight, added in
        if added { return }
        progress.addChild(newProgress, withPendingUnitCount: weight)
        added = true
    }
    
    let loadProgress = nasr.load { result in
        switch result {
            case .success:
                print("Parsing...")
                
                var airportsAdded = false
                try! nasr.parse(.airports, progressHandler: { addProgress($0, 100, &airportsAdded) }, errorHandler: { error in
                    fputs("\(error)\n", stderr)
                    return true
                })
                
                var ARTCCsAdded = false
                try! nasr.parse(.ARTCCFacilities, progressHandler: { addProgress($0, 20, &ARTCCsAdded) }, errorHandler: { error in
                    fputs("\(error)\n", stderr)
                    return true
                })

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
                } catch (let error) {
                    fatalError("\(error)")
                }
                
            case .failure(let error):
                fatalError("\(error)")
        }
        group.leave()
    }
    progress.addChild(loadProgress, withPendingUnitCount: 10)
    
    group.wait()
}

if #available(OSX 10.15, *) {
    testWithCombine()
} else {
    testWithCallbacks()
}
