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
    
    nasr.load { result in
        switch result {
            case .success:
                print("Parsing...")
                
                try! nasr.parse(.airports, errorHandler: { error in
                    fputs("\(error)\n", stderr)
                    return true
                })
                
                try! nasr.parse(.ARTCCFacilities, errorHandler: { error in
                    fputs("\(error)\n", stderr)
                    return true
                })
                
                try! nasr.parse(.flightServiceStations, errorHandler: { error in
                    fputs("\(error)\n", stderr)
                    return true
                })
                
                do {
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
    
    group.wait()
}

if #available(OSX 10.15, *) {
    testWithCombine()
} else {
    testWithCallbacks()
}
