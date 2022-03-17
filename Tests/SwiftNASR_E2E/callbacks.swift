import Foundation
import SwiftNASR

class CallbacksTest: E2ETest {
    private var airportsDone = false,
                    ARTCCsDone = false,
                    FSSesDone = false
    
    override func test() {
        loadingQueue.async { self.load() }
        loadingQueue.async {
            self.waitAndSave()
            self.group.leave()
        }
    }

    private func parseAirports() {
        var airportsAdded = false
        try! nasr.parse(.airports, progressHandler: {
            self.addProgress($0, weight: 100, added: &airportsAdded)
        }, errorHandler: { error in
            fputs("\(error)\n", stderr)
            return true
        }, completionHandler: { self.airportsDone = true })
    }
    
    private func parseARTCCs() {
        var ARTCCsAdded = false
        try! nasr.parse(.ARTCCFacilities, progressHandler: {
            self.addProgress($0, weight: 20, added: &ARTCCsAdded)
        }, errorHandler: { error in
            fputs("\(error)\n", stderr)
            return true
        }, completionHandler: { self.ARTCCsDone = true})
    }
    
    private func parseFSSes() {
        var FSSesAdded = false
        try! nasr.parse(.flightServiceStations, progressHandler: {
            self.addProgress($0, weight: 10, added: &FSSesAdded)
        }, errorHandler: { error in
            fputs("\(error)\n", stderr)
            return true
        }, completionHandler: { self.FSSesDone = true })
    }
    
    private func load() {
        print("Loading…")
        let loadProgress = nasr.load { result in
            switch result {
            case .success:
                self.parseAirports()
                self.parseARTCCs()
                self.parseFSSes()
            case let .failure(error):
                fatalError("\(error)")
            }
        }
        progress.addChild(loadProgress, withPendingUnitCount: 10)
    }
    
    private func waitAndSave() {
        repeat {
            sleep(1)
        } while (airportsDone == false || ARTCCsDone == false || FSSesDone == false)
        
        print("Saving…")
        saveData()
    }
    
    private func addProgress(_ newProgress: Progress, weight: Int64, added: inout Bool) -> Void {
        if added { return }
        updatingQueue.async { self.progress.addChild(newProgress, withPendingUnitCount: weight) }
        added = true
    }
}
