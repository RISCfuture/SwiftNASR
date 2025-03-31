import Quick
import XCTest

@testable import SwiftNASRTests

QCKMain([
    AirportParserSpec.self,
    ArchiveDataDistributionSpec.self,
    ArchiveDataDownloaderSpec.self,
    ArchiveFileDistributionSpec.self,
    ArchiveFileDownloaderSpec.self,
    ArchiveLoaderSpec.self,
    ARTCCParserSpec.self,
    AttendanceScheduleSpec.self,
    CycleSpec.self,
    DirectoryDistributionSpec.self,
    DirectoryLoaderSpec.self,
    FSSParserSpec.self,
    JSONZipCoderSpec.self,
    NASRDataSpec.self,
    ParserSpec.self,
    RecordEnumSpec.self,
    StateParserSpec.self,
    StringSpec.self,
    WriterSpec.self
])
