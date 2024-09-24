import Foundation
import Quick
import Nimble
import ZIPFoundation

@testable import SwiftNASR

@available(macOS 10.12, *)
class ArchiveFileDownloaderSpec: QuickSpec {
    private static var downloader: ArchiveFileDownloader {
        let d = ArchiveFileDownloader(cycle: Cycle(year: 2020, month: 1, day: 30))
        d.session = mockSession
        return d
    }

    private static var mockSession = MockURLSession()
    private class var mockData: Data {
        let data = "Hello, world!".data(using: .isoLatin1)!
        let archive = try! Archive(accessMode: .create)
        try! archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
            return data.subdata(in: Data.Index(position)..<(Int(position)+size))
        }
        return archive.data!
    }
    private static var mockURL = URL(string: "http://test.host")!

    override class func spec() {
        afterSuite {
            self.mockSession.cleanup()
        }

        describe("load") {
            context("2xx response") {
                beforeEach {
                    let mockResponse = HTTPURLResponse(url: self.mockURL, statusCode: 200, httpVersion: "1.1", headerFields: [:])
                    self.mockSession.nextResponse = (self.mockData, mockResponse, nil)
                }

                it("calls back with the file") {
                    waitUntil { done in
                        self.downloader.load { result in
                            expect(result).to(beSuccess { distribution in
                                let file = (distribution as! ArchiveFileDistribution).location
                                expect(try! Data(contentsOf: file)).to(equal(self.mockData))
                            })
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
                        self.downloader.load { result in
                            expect(result).to(beFailure { error in
                                expect(error).to(matchError(Error.badResponse(URLResponse())))
                            })
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
                        self.downloader.load { result in
                            expect(result).to(beFailure(matchError(NSError(domain: "TestDomain", code: -1))))
                            done()
                        }
                    }
                }
            }
        }
    }
}
