import Foundation

struct MockResponse {
    var data: Data?
    var error: Error?
    var response: URLResponse?
}

class MockURLProtocol: URLProtocol {
    // Quick tests do not run in parallel so access should always be synchronous
    nonisolated(unsafe) static var nextResponse: MockResponse?
    nonisolated(unsafe) static var lastURL: URL?

    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: (any URLProtocolClient)?) {
        Self.lastURL = request.url
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    override class func canInit(with _: URLRequest) -> Bool {
        // Indicate that this protocol can handle all types of requests
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let response = Self.nextResponse else {
            fatalError("Did not configure a MockResponse for MockURLProtocol before use")
        }

        if let data = response.data {
            self.client?.urlProtocol(self, didLoad: data)
        }

        if let response = response.response {
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        if let error = response.error {
            self.client?.urlProtocol(self, didFailWithError: error)
        } else {
            self.client?.urlProtocolDidFinishLoading(self)
        }

        Self.nextResponse = nil
    }

    override func stopLoading() {
        // Required, but not used in this mock
    }
}
