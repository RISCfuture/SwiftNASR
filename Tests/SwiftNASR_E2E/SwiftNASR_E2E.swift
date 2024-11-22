import Foundation
import SwiftNASR
import ArgumentParser

actor ProgressTracker {
    var progress: Progress
    var isStarted = false

    var fractionCompleted: Double {
        get async {
            progress.fractionCompleted
        }
    }

    var isFinished: Bool {
        get async {
            isStarted && progress.isFinished
        }
    }

    init() {
        self.progress = Progress(totalUnitCount: 100)
    }

    func addChild(_ child: Progress, withPendingUnitCount inUnitCount: Int64) {
        self.progress.addChild(child, withPendingUnitCount: inUnitCount)
        isStarted = true
    }
}

@main struct SwiftNASR_E2E: AsyncParsableCommand {
    @Option(name: .shortAndLong,
            help: "The working directory to store the distribution data.",
            transform: { URL(filePath: $0) })
    var workingDirectory = URL.currentDirectory()

    private var distributionURL: URL { workingDirectory.appendingPathComponent("distribution.zip") }

    private let progress = ProgressTracker()
    private var progressTask: Task<Void, Swift.Error>? = nil

    lazy var nasr: NASR = {
        if FileManager.default.fileExists(atPath: distributionURL.path) {
            return NASR.fromLocalArchive(distributionURL)
        } else {
            return NASR.fromInternetToFile(distributionURL)!
        }
    }()

    mutating func run() async throws {
        print("Loading…")
        let progress = self.progress
        try await nasr.load(withProgress: { child in
            Task { @MainActor in await progress.addChild(child, withPendingUnitCount: 5) }
        })
        print("Done loading; parsing…")

        progressTask = trackProgress()
        try await parseValues()

        print("Saving…")
        await saveData()
    }

    private mutating func parseValues() async throws {
        let progress = self.progress
        let nasr = self.nasr

        async let airports = try nasr.parse(.airports, withProgress: { child in
            Task { @MainActor in await progress.addChild(child, withPendingUnitCount: 75) }
        }) { error in
            fputs("\(error)\n", stderr)
            return true
        }

        async let artccs = try nasr.parse(.ARTCCFacilities, withProgress: { child in
            Task { @MainActor in await progress.addChild(child, withPendingUnitCount: 5) }
        }) { error in
            fputs("\(error)\n", stderr)
            return true
        }

        async let fsses = try nasr.parse(.flightServiceStations, withProgress: { child in
            Task { @MainActor in await progress.addChild(child, withPendingUnitCount: 5) }
        }) { error in
            fputs("\(error)\n", stderr)
            return true
        }

        async let navaids = try nasr.parse(.navaids, withProgress: { child in
            Task { @MainActor in await progress.addChild(child, withPendingUnitCount: 10) }
        }) { error in
            fputs("\(error)\n", stderr)
            return true
        }

        let _ = try await [airports, artccs, fsses, navaids]
    }

    private mutating func saveData() async {
        await print("Airports: \(nasr.data.airports!.count)")
        await print("ARTCCs: \(nasr.data.ARTCCs!.count)")
        await print("FSSes: \(nasr.data.FSSes!.count)")
        await print("Navaids: \(nasr.data.navaids!.count)")

        do {
            let encoder = JSONZipEncoder()
            let data = try await encoder.encode(NASRDataCodable(data: nasr.data))

            let outPath = workingDirectory.appendingPathComponent("distribution.json.zip")
            try data.write(to: outPath)
            print("JSON file written to \(outPath)")
        } catch (let error) {
            fatalError("\(error)")
        }
    }

    private func trackProgress() -> Task<Void, Swift.Error> {
        Task.detached {
            repeat {
                try await Task.sleep(for: .seconds(0.1))
                await renderProgressBar(progress: self.progress)

            } while await !self.progress.isFinished
        }
    }

    @MainActor
    private func renderProgressBar(progress: ProgressTracker, barWidth: Int = 80) async {
        let percent = await Int((progress.fractionCompleted * 100).rounded())

        let reservedSpace = 10 // Reserve space for percentage and brackets
        let barWidth = max(terminalWidth() - reservedSpace, 10) // Ensure minimum bar width

        let completedWidth = await Int(progress.fractionCompleted * Double(barWidth))
        let remainingWidth = barWidth - completedWidth

        let bar = String(repeating: "=", count: completedWidth) + String(repeating: " ", count: remainingWidth)
        print("\r[\(bar)] \(percent)%", terminator: "")
        fflush(stdout) // Ensure that the output is flushed immediately
    }

    private func terminalWidth() -> Int {
        var w = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 {
            return Int(w.ws_col)
        } else {
            return 80 // Default terminal width if ioctl fails
        }
    }

    private enum CodingKeys: String, CodingKey {
        case workingDirectory
    }
}
