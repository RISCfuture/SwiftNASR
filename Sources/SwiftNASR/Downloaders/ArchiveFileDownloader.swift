import Foundation
import Combine

/**
 A downloader that downloads a distribution archive to a file on disk.
 */

public class ArchiveFileDownloader: Downloader {
    
    /// The `URLSession` to use for downloading.
    public var session = URLSession.shared
    
    /// The location to save the downloaded archive. If `nil`, saves to a
    /// tempfile.
    public var location: URL? = nil
    
    /**
     Creates a new downloader.
     
     - Parameter cycle: The cycle to download NASR data for. If not specified,
                        uses the current cycle.
     - Parameter location: The location to save the downloaded archive. If
                           `nil`, saves to a tempfile.
     */

    public init(cycle: Cycle? = nil, location: URL? = nil) {
        if let cycle = cycle { super.init(cycle: cycle) }
        else { super.init() }
        self.location = location
    }

    override public func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, callback: @escaping (Result<Distribution, Swift.Error>) -> Void) {
        let task = session.downloadTask(with: cycleURL) { tempfileURL, response, error in
            do {
                if let error = error { callback(.failure(error)) }
                else if let response = response {
                    let HTTPResponse = response as! HTTPURLResponse
                    if HTTPResponse.statusCode/100 != 2 { callback(.failure(Error.badResponse(HTTPResponse))) }
                    else if let tempfileURL = tempfileURL {
                        if let location = self.location {
                            try FileManager.default.copyItem(at: tempfileURL, to: location)
                            guard let distribution = ArchiveFileDistribution(location: location) else {
                                callback(.failure(Error.badData))
                                return
                            }
                            callback(.success(distribution))
                        }
                        else {
                            guard let distribution = ArchiveFileDistribution(location: tempfileURL) else {
                                callback(.failure(Error.badData))
                                return
                            }
                            callback(.success(distribution))
                        }
                    }
                    else {
                        callback(.failure(Error.noFile))
                    }
                }
            } catch (let error) {
                callback(.failure(error))
                return
            }
        }
        progressHandler(task.progress)
        task.resume()
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public override func loadPublisher(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) -> AnyPublisher<Distribution, Swift.Error> {
        return Future { promise in
            let task = self.session.downloadTask(with: self.cycleURL) { tempfileURL, response, error in
                do {
                    if let error = error {
                        throw error
                    }
                    else if let response = response {
                        let HTTPResponse = response as! HTTPURLResponse
                        if HTTPResponse.statusCode/100 != 2 {
                            throw Error.badResponse(HTTPResponse)
                        }
                        else if let tempfileURL = tempfileURL {
                            if let location = self.location {
                                try FileManager.default.copyItem(at: tempfileURL, to: location)
                                guard let distribution = ArchiveFileDistribution(location: location) else {
                                    throw Error.badData
                                }
                                promise(.success(distribution))
                            }
                            else {
                                guard let distribution = ArchiveFileDistribution(location: tempfileURL) else {
                                    throw Error.badData
                                }
                                promise(.success(distribution))
                            }
                        }
                        else {
                            throw Error.noFile
                        }
                    }
                } catch (let error) {
                    promise(.failure(error))
                }
            }
            progressHandler(task.progress)
            task.resume()
        }.eraseToAnyPublisher()
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    override public func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) async throws -> Distribution {
        let delegate = DownloadDelegate()
        progressHandler(delegate.progress)
        
        let (tempfileURL, response) = try await session.download(from: cycleURL, delegate: delegate)
        
        let HTTPResponse = response as! HTTPURLResponse
        if HTTPResponse.statusCode/100 != 2 { throw Error.badResponse(HTTPResponse) }
        
        if let location = self.location {
            try FileManager.default.copyItem(at: tempfileURL, to: location)
            guard let distribution = ArchiveFileDistribution(location: location) else { throw Error.badData }
            return distribution
        }
        else {
            guard let distribution = ArchiveFileDistribution(location: tempfileURL) else { throw Error.badData }
            return distribution
        }
    }
}
