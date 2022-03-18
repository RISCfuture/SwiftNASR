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
        try! nasr.parse(.airports, withProgress: {
            self.progress.addChild($0, withPendingUnitCount: 89)
        }, errorHandler: { error in
            fputs("\(error)\n", stderr)
            return true
        }, completionHandler: { self.airportsDone = true })
    }
    
    private func parseARTCCs() {
        try! nasr.parse(.ARTCCFacilities, withProgress: {
            self.progress.addChild($0, withPendingUnitCount: 5)
        }, errorHandler: { error in
            fputs("\(error)\n", stderr)
            return true
        }, completionHandler: { self.ARTCCsDone = true})
    }
    
    private func parseFSSes() {
        try! nasr.parse(.flightServiceStations, withProgress: {
            self.progress.addChild($0, withPendingUnitCount: 5)
        }, errorHandler: { error in
            fputs("\(error)\n", stderr)
            return true
        }, completionHandler: { self.FSSesDone = true })
    }
    
    private func load() {
        print("Loading…")
        nasr.load(withProgress: { self.progress.addChild($0, withPendingUnitCount: 1) }) { result in
            switch result {
            case .success:
                self.parseAirports()
                self.parseARTCCs()
                self.parseFSSes()
            case let .failure(error):
                fatalError("\(error)")
            }
        }
    }
    
    private func waitAndSave() {
        repeat {
            sleep(1)
        } while (airportsDone == false || ARTCCsDone == false || FSSesDone == false)
        
        print("Saving…")
        saveData()
    }
}
