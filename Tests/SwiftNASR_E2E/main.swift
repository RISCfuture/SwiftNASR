import Foundation
import Dispatch
import SwiftNASR
import Darwin

let workingURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let distributionURL = workingURL.appendingPathComponent("distribution.zip")

let NASR: SwiftNASR
if FileManager.default.fileExists(atPath: distributionURL.path) {
    NASR = SwiftNASR.fromLocalArchive(distributionURL)
} else {
    NASR = SwiftNASR.fromInternetToFile(distributionURL)!
}

let group = DispatchGroup()
group.enter()

print("Loading...")

NASR.load { result in
    switch result {
        case .success:
            print("Parsing...")
            
            try! NASR.parse(.airports, errorHandler: { error in
                fputs("\(error)\n", stderr)
                return true
            })

            try! NASR.parse(.ARTCCFacilities, errorHandler: { error in
                fputs("\(error)\n", stderr)
                return true
            })
            
            try! NASR.parse(.flightServiceStations, errorHandler: { error in
                fputs("\(error)\n", stderr)
                return true
            })
            
            do {
                let encoder = JSONZipEncoder()
                let data = try encoder.encode(NASR.data)
                
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
