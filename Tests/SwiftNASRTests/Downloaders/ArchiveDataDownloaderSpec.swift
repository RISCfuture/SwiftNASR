import Foundation
import Quick
import Nimble
import ZIPFoundation

@testable import SwiftNASR

class ArchiveDataDownloaderSpec: AsyncSpec {
    private static var mockData: Data {
        let data = "Hello, world!".data(using: .isoLatin1)!
        let archive = try! Archive(accessMode: .create)
        try! archive.addEntry(with: "APT.TXT", type: .file, uncompressedSize: Int64(data.count)) { (position: Int64, size: Int) in
            return data.subdata(in: Data.Index(position)..<(Int(position)+size))
        }
        return archive.data!
    }

    override class func spec() {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: sessionConfig)

        let downloader = ArchiveDataDownloader(cycle: Cycle(year: 2020, month: 1, day: 30), session: mockSession)
        let mockURL = URL(string: "http://test.host")!

        describe("load") {
            context("2xx response") {
                beforeEach {
                    let mockResponse = HTTPURLResponse(url: mockURL, statusCode: 200, httpVersion: "1.1", headerFields: [:])
                    MockURLProtocol.nextResponse = .init(data: mockData, response: mockResponse)
                }

                it("calls back with the data") {
                    let distribution = try await downloader.load() as! ArchiveDataDistribution
                    expect(distribution.data).to(equal(mockData))
                    expect(MockURLProtocol.lastURL!.absoluteString)
                        .to(equal("https://nfdc.faa.gov/webContent/28DaySub/28DaySubscription_Effective_2020-01-30.zip"))

                }
            }

            context("bad HTTP code") {
                let mockResponse = HTTPURLResponse(url: mockURL, statusCode: 404, httpVersion: "1.1", headerFields: [:])

                beforeEach {
                    MockURLProtocol.nextResponse = .init(data: mockData, response: mockResponse)
                }

                it("calls back with an error") {
                    await expect { try await downloader.load() }
                        .to(throwError(Error.badResponse(URLResponse())))
                }
            }

            context("HTTP error") {
                beforeEach {
                    MockURLProtocol.nextResponse = .init(error: NSError(domain: "TestDomain", code: -1, userInfo: [:]))
                }

                it("calls back with an error") {
                    await expect { try await downloader.load() }
                        .to(throwError { (error: NSError) in
                            expect(error.domain).to(equal("TestDomain"))
                            expect(error.code).to(equal(-1))
                        })
                }
            }
        }
    }
}
