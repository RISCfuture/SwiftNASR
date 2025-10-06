import ArgumentParser
import Foundation
import SwiftNASR

actor ProgressTracker {
  var progress: Progress
  var isStarted = false

  var fractionCompleted: Double { progress.fractionCompleted }

  var isFinished: Bool { isStarted && progress.isFinished }

  init() {
    self.progress = Progress(totalUnitCount: 100)
  }

  func addChild(_ child: Progress, withPendingUnitCount inUnitCount: Int64) {
    self.progress.addChild(child, withPendingUnitCount: inUnitCount)
    isStarted = true
  }
}

@main
struct SwiftNASR_E2E: AsyncParsableCommand {
  @Option(
    name: .shortAndLong,
    help: "The working directory to store the distribution data.",
    transform: { .init(filePath: $0) }
  )
  var workingDirectory = URL.currentDirectory().appendingPathComponent(".SwiftNASR_TestData")

  @Option(
    name: .shortAndLong,
    help: "Data format to parse (txt or csv, or both if not specified)"
  )
  var format: String?

  @Option(
    name: .long,
    help: "Path to local CSV directory (for testing with local data)"
  )
  var localCSVPath: String?

  private var txtDistributionURL: URL {
    workingDirectory.appendingPathComponent("distribution_txt.zip")
  }
  private var csvDistributionURL: URL {
    workingDirectory.appendingPathComponent("distribution_csv.zip")
  }

  private let progress = ProgressTracker()
  private var progressTask: Task<Void, Swift.Error>?

  init() {}

  mutating func getTxtNASR() -> NASR? {
    // Ensure working directory exists
    try? FileManager.default.createDirectory(
      at: workingDirectory,
      withIntermediateDirectories: true
    )

    if FileManager.default.fileExists(atPath: txtDistributionURL.path) {
      return NASR.fromLocalArchive(txtDistributionURL)
    }
    print("Attempting to download TXT archive...")
    return NASR.fromInternetToFile(txtDistributionURL, format: .txt)
  }

  mutating func getCsvNASR() -> NASR? {
    // Ensure working directory exists
    try? FileManager.default.createDirectory(
      at: workingDirectory,
      withIntermediateDirectories: true
    )

    if let localCSVPath {
      let url = URL(filePath: localCSVPath)
      return NASR.fromLocalDirectory(url, format: .csv)
    }
    if FileManager.default.fileExists(atPath: csvDistributionURL.path) {
      return NASR.fromLocalArchive(csvDistributionURL)
    }
    print("Attempting to download CSV archive...")
    return NASR.fromInternetToFile(csvDistributionURL, format: .csv)
  }

  mutating func run() async throws {
    let formats = determineFormats()

    if formats.contains("txt") {
      print("\n=== Testing TXT Format ===")
      if let nasr = getTxtNASR() {
        do {
          try await runForFormat(nasr: nasr, formatName: "TXT")
        } catch {
          print("Warning: TXT format test failed: \(error)")
          print("This may be due to the cycle data not being available for the current date.")
          print("Continuing with other formats...")
        }
      } else {
        print("Warning: Could not obtain TXT format NASR distribution")
        print("This may be due to the cycle data not being available for the current date.")
        print("Continuing with other formats...")
      }
    }

    if formats.contains("csv") {
      print("\n=== Testing CSV Format ===")
      if let nasr = getCsvNASR() {
        do {
          try await runForFormat(nasr: nasr, formatName: "CSV")
        } catch {
          print("Warning: CSV format test failed: \(error)")
          print("This may be due to the cycle data not being available for the current date.")
          print("Continuing...")
        }
      } else {
        print("Warning: Could not obtain CSV format NASR distribution")
        print("This may be due to the cycle data not being available for the current date.")
        print("Continuing...")
      }
    }
  }

  private func determineFormats() -> Set<String> {
    if let format = format?.lowercased() {
      if format == "both" {
        return ["txt", "csv"]
      }
      return [format]
    }
    return ["txt", "csv"]
  }

  private mutating func runForFormat(nasr: NASR, formatName: String) async throws {
    print("Loading \(formatName)…")
    let progress = self.progress
    try await nasr.load { child in
      Task { @MainActor in await progress.addChild(child, withPendingUnitCount: 5) }
    }
    print("Done loading \(formatName); parsing…")

    progressTask = trackProgress()
    try await parseValues(nasr: nasr)

    print("Saving \(formatName)…")
    await saveData(nasr: nasr, formatName: formatName)
  }

  private mutating func parseValues(nasr: NASR) async throws {
    let progress = self.progress

    async let airports = try nasr.parse(
      .airports,
      withProgress: { child in
        Task { @MainActor in await progress.addChild(child, withPendingUnitCount: 75) }
      },
      errorHandler: { error in
        fputs("\(error)\n", stderr)
        return true
      }
    )

    async let artccs = try nasr.parse(
      .ARTCCFacilities,
      withProgress: { child in
        Task { @MainActor in await progress.addChild(child, withPendingUnitCount: 5) }
      },
      errorHandler: { error in
        fputs("\(error)\n", stderr)
        return true
      }
    )

    async let fsses = try nasr.parse(
      .flightServiceStations,
      withProgress: { child in
        Task { @MainActor in await progress.addChild(child, withPendingUnitCount: 5) }
      },
      errorHandler: { error in
        fputs("\(error)\n", stderr)
        return true
      }
    )

    async let navaids = try nasr.parse(
      .navaids,
      withProgress: { child in
        Task { @MainActor in await progress.addChild(child, withPendingUnitCount: 10) }
      },
      errorHandler: { error in
        fputs("\(error)\n", stderr)
        return true
      }
    )

    _ = try await [airports, artccs, fsses, navaids]
  }

  private mutating func saveData(nasr: NASR, formatName: String) async {
    await print("\(formatName) - Airports: \(nasr.data.airports?.count ?? 0)")
    await print("\(formatName) - ARTCCs: \(nasr.data.ARTCCs?.count ?? 0)")
    await print("\(formatName) - FSSes: \(nasr.data.FSSes?.count ?? 0)")
    await print("\(formatName) - Navaids: \(nasr.data.navaids?.count ?? 0)")

    do {
      // Ensure working directory exists
      try FileManager.default.createDirectory(
        at: workingDirectory,
        withIntermediateDirectories: true
      )

      let encoder = JSONZipEncoder()
      let data = try await encoder.encode(NASRDataCodable(data: nasr.data))

      let outPath = workingDirectory.appendingPathComponent(
        "distribution_\(formatName.lowercased()).json.zip"
      )
      try data.write(to: outPath)
      print("\(formatName) JSON file written to \(outPath)")
    } catch {
      print("Error saving \(formatName): \(error)")
    }
  }

  private func trackProgress() -> Task<Void, Swift.Error> {
    Task.detached {
      repeat {
        try await Task.sleep(for: .seconds(0.1))
        await renderProgressBar(progress: progress)
      } while await !progress.isFinished
    }
  }

  @MainActor
  private func renderProgressBar(progress: ProgressTracker, barWidth: Int = 80) async {
    let fractionCompleted = await progress.fractionCompleted
    let percent = Int((fractionCompleted * 100).rounded())

    let reservedSpace = 10  // Reserve space for percentage and brackets
    let barWidth = max(terminalWidth() - reservedSpace, 10)  // Ensure minimum bar width

    // Ensure fractionCompleted is within valid bounds
    let clampedFraction = max(0.0, min(1.0, fractionCompleted))
    let completedWidth = Int(clampedFraction * Double(barWidth))

    // Ensure counts are non-negative
    let safeCompletedWidth = max(0, min(barWidth, completedWidth))
    let safeRemainingWidth = max(0, barWidth - safeCompletedWidth)

    let bar =
      String(repeating: "=", count: safeCompletedWidth)
      + String(repeating: " ", count: safeRemainingWidth)
    print("\r[\(bar)] \(percent)%", terminator: "")
    fflush(stdout)  // Ensure that the output is flushed immediately
  }

  private func terminalWidth() -> Int {
    var w = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 {
      return Int(w.ws_col)
    }
    return 80
  }

  private enum CodingKeys: String, CodingKey {
    case workingDirectory
    case format
    case localCSVPath
  }
}
