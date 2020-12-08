import Foundation

@available(OSX 10.12, *)
class MockURLSession: URLSession {
    var nextResponse: (Data?, URLResponse?, Error?) = (nil, nil, nil)
    var lastURL: URL? = nil

    var tempfiles: Array<URL> = []

    override func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        lastURL = url
        completionHandler(nextResponse.0, nextResponse.1, nextResponse.2)
        return URLSession.shared.dataTask(with: url)
    }

    override func downloadTask(with url: URL, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTask {
        lastURL = url

        if let data = nextResponse.0 {
            let tempfile = FileManager.default.temporaryDirectory
                .appendingPathComponent(ProcessInfo().globallyUniqueString)
            try! data.write(to: tempfile, options: .atomic)
            tempfiles.append(tempfile)
            completionHandler(tempfile, nextResponse.1, nextResponse.2)
        }
        else {
            completionHandler(nil, nextResponse.1, nextResponse.2)
        }

        return URLSession.shared.downloadTask(with: url)
    }

    func cleanup() {
        for tempfile in tempfiles {
            do {
                try FileManager.default.removeItem(at: tempfile)
            } catch {
                // do nothing
            }
        }
        tempfiles.removeAll(keepingCapacity: false)
    }
}

