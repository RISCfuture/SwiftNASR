import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Synchronization

struct MockResponse {
  var data: Data?
  var error: Error?
  var response: URLResponse?
}

class MockURLProtocol: URLProtocol {
  // `URLProtocol`'s `init`/`startLoading` are synchronous callbacks driven by
  // `URLSession`, so an actor doesn't fit; a Mutex provides real mutual exclusion
  // for this shared test fixture without requiring the protected state to be
  // statically `Sendable`.
  private static let state = Mutex(State())

  static var nextResponse: MockResponse? {
    get { state.withLock { $0.nextResponse } }
    set { state.withLock { $0.nextResponse = newValue } }
  }

  static var lastURL: URL? {
    get { state.withLock { $0.lastURL } }
    set { state.withLock { $0.lastURL = newValue } }
  }

  override required init(
    request: URLRequest,
    cachedResponse: CachedURLResponse?,
    client: (any URLProtocolClient)?
  ) {
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

  private struct State {
    var nextResponse: MockResponse?
    var lastURL: URL?
  }
}
