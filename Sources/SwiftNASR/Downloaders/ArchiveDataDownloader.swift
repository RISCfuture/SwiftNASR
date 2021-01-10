import Foundation
import Combine

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
                if HTTPResponse.statusCode/100 != 2 { callback(.failure(Downloader.Error.badResponse(HTTPResponse))) }
                else if let data = data {
                    guard let distribution = ArchiveDataDistribution(data: data) else {
                        callback(.failure(Downloader.Error.badData))
                        return
                    }
                    callback(.success(distribution))

                }
                else { callback(.failure(Downloader.Error.noData)) }
            }
        }
        task.resume()
        return task.progress
    }
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public override func load() -> AnyPublisher<Distribution, Swift.Error> {
        return session.dataTaskPublisher(for: cycleURL)
            .tryMap { data, response -> Distribution in
                guard let HTTPResponse = response as? HTTPURLResponse, HTTPResponse.statusCode == 200 else {
                    throw Downloader.Error.badResponse(response)
                }
                guard let distribution = ArchiveDataDistribution(data: data) else {
                    throw Downloader.Error.badData
                }
                return distribution
            }.share().eraseToAnyPublisher()
    }
}
