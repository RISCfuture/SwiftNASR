import Foundation
import Combine

class ObservedProgress: Progress {
    private var observation: NSKeyValueObservation!
    
    init(child: Progress, queue: DispatchQueue) {
        super.init(parent: nil, userInfo: nil)
        
        observation = child.observe(\.completedUnitCount) { _, change in
            if let count = change.newValue {
                queue.async { self.completedUnitCount = count }
            }
        }
        
        totalUnitCount = child.totalUnitCount
        completedUnitCount = child.completedUnitCount
    }
    
    deinit {
        observation.invalidate()
    }
}

/**
 A downloader that downloads a distribution archive into memory. No data is
 saved to disk and no buffering is done.
 */

public class ArchiveDataDownloader: Downloader {
    
    /// The `URLSession` to use for downloading.
    public var session = URLSession.shared

    override public func load(callback: @escaping (Result<Distribution, Swift.Error>) -> Void) -> Progress {
        let task = session.dataTask(with: cycleURL) { data, response, error in
            if let error = error { callback(.failure(error)) }
            else if let response = response {
                let HTTPResponse = response as! HTTPURLResponse
                if HTTPResponse.statusCode/100 != 2 { callback(.failure(Error.badResponse(HTTPResponse))) }
                else if let data = data {
                    guard let distribution = ArchiveDataDistribution(data: data) else {
                        callback(.failure(Error.badData))
                        return
                    }
                    callback(.success(distribution))

                }
                else { callback(.failure(Error.noData)) }
            }
        }
        let progress = ObservedProgress(child: task.progress, queue: Self.progressQueue)
        task.resume()
        return progress
    }
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public override func load() -> AnyPublisher<Distribution, Swift.Error> {
        return session.dataTaskPublisher(for: cycleURL)
            .tryMap { data, response -> Distribution in
                guard let HTTPResponse = response as? HTTPURLResponse, HTTPResponse.statusCode == 200 else {
                    throw Error.badResponse(response)
                }
                guard let distribution = ArchiveDataDistribution(data: data) else {
                    throw Error.badData
                }
                return distribution
            }.share().eraseToAnyPublisher()
    }
}
