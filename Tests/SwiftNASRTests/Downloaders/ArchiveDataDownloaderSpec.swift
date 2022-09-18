import Foundation
import Quick
import Nimble
import ZIPFoundation

@testable import SwiftNASR

@available(macOS 10.12, *)
class ArchiveDataDownloaderSpec: QuickSpec {
    private var downloader: ArchiveDataDownloader {
        let d = ArchiveDataDownloader(cycle: Cycle(year: 2020, month: 1, day: 30))
        d.session = mockSession
        return d
    }

    private var mockSession = MockURLSession()
    private var mockData: Data {
        let data = "Hello, world!".data(using: .ascii)!
        let archive = Archive(accessMode: .create)!
        try! archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
            return data.subdata(in: Data.Index(position)..<(Int(position)+size))
        }
        return archive.data!
    }
    private var mockURL = URL(string: "http://test.host")!

    override func spec() {
        describe("load") {
            context("2xx response") {
                beforeEach {
                    let mockResponse = HTTPURLResponse(url: self.mockURL, statusCode: 200, httpVersion: "1.1", headerFields: [:])
                    self.mockSession.nextResponse = (self.mockData, mockResponse, nil)
                }

                it("calls back with the data") {
                    waitUntil { done in
                        _ = self.downloader.load { result in
                            expect({
                                switch result {
                                case .success(let distribution):
                                    let data = (distribution as! ArchiveDataDistribution).data
                                    if data == self.mockData {
                                        return { .succeeded }
                                    } else {
                                        return { .failed(reason: "wrong data") }
                                    }
                                case .failure(let error):
                                    return { .failed(reason: "\(error)") }
                                }
                                }).to(succeed())
                            expect(self.mockSession.lastURL!.absoluteString)
                                .to(equal("https://nfdc.faa.gov/webContent/28DaySub/28DaySubscription_Effective_2020-01-30.zip"))
                            done()
                        }
                    }
                }
            }

            context("bad HTTP code") {
                let mockResponse = HTTPURLResponse(url: self.mockURL, statusCode: 404, httpVersion: "1.1", headerFields: [:])

                beforeEach {
                    self.mockSession.nextResponse = (self.mockData, mockResponse, nil)
                }

                it("calls back with an error") {
                    waitUntil { done in
                        _ = self.downloader.load { result in
                            expect({
                                switch result {
                                case .success:
                                    return { .failed(reason: "expected error, got data") }
                                case .failure(let error):
                                    switch error {
                                    case Error.badResponse:
                                        return { .succeeded }
                                    default:
                                        return { .failed(reason: "wrong error \(error)") }
                                    }
                                }
                                }).to(succeed())
                            done()
                        }
                    }
                }
            }

            context("HTTP error") {
                beforeEach {
                    self.mockSession.nextResponse = (nil, nil, NSError(domain: "TestDomain", code: -1, userInfo: [:]))
                }

                it("calls back with an error") {
                    waitUntil { done in
                        _ = self.downloader.load { result in
                            expect({
                                switch result {
                                case .success:
                                    return { .failed(reason: "expected error, got data") }
                                case .failure(let error):
                                    let cocoaError = error as NSError
                                    if cocoaError.domain == "TestDomain" && cocoaError.code == -1 {
                                        return { .succeeded }
                                    } else {
                                        return { .failed(reason: "wrong error \(error)") }
                                    }
                                }
                                }).to(succeed())
                            done()
                        }
                    }
                }
            }
        }
    }
}
