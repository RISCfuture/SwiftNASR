import Foundation

/**
 A downloader that downloads a distribution archive into memory. No data is
 saved to disk and no buffering is done.
 */

public class ArchiveDataDownloader: Downloader {
    
    /// The `URLSession` to use for downloading.
    public var session = URLSession.shared

    override public func load(callback: @escaping (Result<Distribution, Swift.Error>) -> Void) {
        session.dataTask(with: cycleURL) { data, response, error in
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
        }.resume()
    }
}
