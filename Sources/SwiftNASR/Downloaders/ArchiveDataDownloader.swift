import Foundation
import Combine

/**
 A downloader that downloads a distribution archive into memory. No data is
 saved to disk and no buffering is done.
 */

public class ArchiveDataDownloader: Downloader {
    
    /// The `URLSession` to use for downloading.
    public var session = URLSession.shared
    
    override public func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, callback: @escaping (Result<Distribution, Swift.Error>) -> Void) {
        let task = session.dataTask(with: cycleURL) { data, response, error in
            if let error = error { callback(.failure(error)) }
            else if let response = response {
                let HTTPResponse = response as! HTTPURLResponse
                if HTTPResponse.statusCode/100 != 2 { callback(.failure(Error.badResponse(HTTPResponse))) }
                else if let data = data {
                    do {
                        let distribution = try ArchiveDataDistribution(data: data)
                        callback(.success(distribution))
                    } catch {
                        callback(.failure(error))
                        return
                    }
                }
                else { callback(.failure(Error.noData)) }
            }
        }
        progressHandler(task.progress)
        task.resume()
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public override func loadPublisher(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) -> AnyPublisher<Distribution, Swift.Error> {
        let task = session.dataTaskPublisher(for: cycleURL)
        session.getTasksWithCompletionHandler { dataTasks, _, _ in
            if let progress = dataTasks.last?.progress {
                progressHandler(progress)
            }
        }
        return task.tryMap { data, response -> Distribution in
            guard let HTTPResponse = response as? HTTPURLResponse, HTTPResponse.statusCode == 200 else {
                throw Error.badResponse(response)
            }
            return try ArchiveDataDistribution(data: data)
        }.share().eraseToAnyPublisher()
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    override public func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) async throws -> Distribution {
        let delegate = DownloadDelegate()
        progressHandler(delegate.progress)
        
        let (data, response) = try await session.data(from: cycleURL, delegate: delegate)
        
        let HTTPResponse = response as! HTTPURLResponse
        if HTTPResponse.statusCode/100 != 2 { throw Error.badResponse(HTTPResponse) }
        
        return try ArchiveDataDistribution(data: data)
    }
}
