import Foundation
import Combine
import SwiftNASR

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class CombineTest: E2ETestWithProgress {
    private var cancellable: AnyCancellable!
    
    override func test() {
        print("Loading…")
        
        cancellable = nasr.loadPublisher(withProgress: { self.progress.addChild($0, withPendingUnitCount: 1) }).map {
            Publishers.CombineLatest3(
                $0.parseAirportsPublisher(errorHandler: { print($0) }, withProgress: { self.progress.addChild($0, withPendingUnitCount: 89) }),
                $0.parseARTCCsPublisher(errorHandler: { print($0) }, withProgress: { self.progress.addChild($0, withPendingUnitCount: 5) }),
                $0.parseFSSesPublisher(errorHandler: { print($0) }, withProgress: { self.progress.addChild($0, withPendingUnitCount: 5) })
            )
        }.switchToLatest()
            .mapError { (error: Swift.Error) -> Swift.Error in print(error); return error }
            .sink(receiveCompletion: { completion in
                print("Saving… \(completion)")
                self.saveData()
                
                self.group.leave()
            }, receiveValue: { _ in })
    }

}
