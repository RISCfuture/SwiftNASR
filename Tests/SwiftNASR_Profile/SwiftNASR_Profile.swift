import ArgumentParser
import Foundation
import SwiftNASR

struct TimingResult {
  let format: String
  let downloadTime: TimeInterval
  let loadTime: TimeInterval
  let parseTime: TimeInterval
  var totalTime: TimeInterval { downloadTime + loadTime + parseTime }

  func printSummary() {
    print("\n\(format) Format Timing:")
    print("  Download: \(String(format: "%.2f", downloadTime))s")
    print("  Load: \(String(format: "%.2f", loadTime))s")
    print("  Parse: \(String(format: "%.2f", parseTime))s")
    print("  Total: \(String(format: "%.2f", totalTime))s")
  }
}

@main
struct SwiftNASR_Profile: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Profile and compare TXT vs CSV parsing performance",
    discussion: """
      This tool downloads and parses NASR data in both TXT and CSV formats,
      measuring the time taken for each step (download, load, parse) to provide
      performance comparisons between the two formats.
      """
  )

  @Option(
    name: .shortAndLong,
    help: "The working directory to store the distribution data.",
    transform: { URL(fileURLWithPath: $0) }
  )
  var workingDirectory = URL.currentDirectory().appendingPathComponent(".SwiftNASR_TestData")

  @Option(
    name: .shortAndLong,
    help: "Which record types to parse (airports, navaids, fsses, artccs, or all)"
  )
  var recordTypes = "all"

  @Flag(
    name: .shortAndLong,
    help: "Skip download if files already exist"
  )
  var skipDownload = false

  @Flag(
    name: .shortAndLong,
    help: "Delete downloaded files after profiling"
  )
  var cleanup = false

  private var txtDistributionURL: URL { workingDirectory.appendingPathComponent("profile_txt.zip") }
  private var csvDistributionURL: URL { workingDirectory.appendingPathComponent("profile_csv.zip") }

  mutating func run() async throws {
    print("SwiftNASR Performance Profiler")
    print("===============================\n")

    var txtResult: TimingResult?
    var csvResult: TimingResult?

    // Profile TXT format
    print("Testing TXT format...")
    do {
      txtResult = try await profileFormat(format: .txt, distributionURL: txtDistributionURL)
    } catch {
      print("Warning: Failed to profile TXT format: \(error)")
      print("This may be due to the cycle data not being available for the current date.")
    }

    // Profile CSV format
    print("\nTesting CSV format...")
    do {
      csvResult = try await profileFormat(format: .csv, distributionURL: csvDistributionURL)
    } catch {
      print("Warning: Failed to profile CSV format: \(error)")
      print("This may be due to the cycle data not being available for the current date.")
    }

    // Print comparison summary if we have both results
    if let txtResult, let csvResult {
      printComparison(txt: txtResult, csv: csvResult)
    } else if txtResult == nil && csvResult == nil {
      print("\nNo formats could be profiled successfully.")
    } else if let txtResult {
      print("\nOnly TXT format profiled successfully.")
      txtResult.printSummary()
    } else if let csvResult {
      print("\nOnly CSV format profiled successfully.")
      csvResult.printSummary()
    }

    // Cleanup if requested
    if cleanup {
      print("\nCleaning up downloaded files...")
      try? FileManager.default.removeItem(at: txtDistributionURL)
      try? FileManager.default.removeItem(at: csvDistributionURL)
    }
  }

  private mutating func profileFormat(format: DataFormat, distributionURL: URL) async throws
    -> TimingResult
  {
    var downloadTime: TimeInterval = 0
    var loadTime: TimeInterval = 0
    var parseTime: TimeInterval = 0

    // Download phase
    let nasr: NASR
    if skipDownload && FileManager.default.fileExists(atPath: distributionURL.path) {
      print("  Using existing file at \(distributionURL.lastPathComponent)")
      nasr = NASR.fromLocalArchive(distributionURL)
    } else {
      print("  Downloading \(format) distribution...")
      let downloadStart = Date()
      guard let downloadedNASR = NASR.fromInternetToFile(distributionURL, format: format) else {
        throw Error.downloadFailed(reason: "Failed to download \(format) distribution")
      }
      nasr = downloadedNASR
      downloadTime = Date().timeIntervalSince(downloadStart)
      print("    Download completed in \(String(format: "%.2f", downloadTime))s")
    }

    // Load phase
    print("  Loading \(format) distribution...")
    let loadStart = Date()
    try await nasr.load()
    loadTime = Date().timeIntervalSince(loadStart)
    print("    Load completed in \(String(format: "%.2f", loadTime))s")

    // Parse phase
    print("  Parsing \(format) data...")
    let parseStart = Date()
    try await parseRecords(nasr: nasr)
    parseTime = Date().timeIntervalSince(parseStart)
    print("    Parse completed in \(String(format: "%.2f", parseTime))s")

    // Print record counts
    await printRecordCounts(nasr: nasr, format: format.rawValue)

    return TimingResult(
      format: format.rawValue,
      downloadTime: downloadTime,
      loadTime: loadTime,
      parseTime: parseTime
    )
  }

  private func parseRecords(nasr: NASR) async throws {
    let types = determineRecordTypes()

    // Parse records in parallel
    await withTaskGroup(of: Void.self) { group in
      if types.contains(.airports) {
        group.addTask {
          _ = try? await nasr.parse(.airports) { _ in true }
        }
      }

      if types.contains(.navaids) {
        group.addTask {
          _ = try? await nasr.parse(.navaids) { _ in true }
        }
      }

      if types.contains(.flightServiceStations) {
        group.addTask {
          _ = try? await nasr.parse(.flightServiceStations) { _ in true }
        }
      }

      if types.contains(.ARTCCFacilities) {
        group.addTask {
          _ = try? await nasr.parse(.ARTCCFacilities) { _ in true }
        }
      }
    }
  }

  private func determineRecordTypes() -> Set<RecordType> {
    switch recordTypes.lowercased() {
      case "airports":
        return [.airports]
      case "navaids":
        return [.navaids]
      case "fsses":
        return [.flightServiceStations]
      case "artccs":
        return [.ARTCCFacilities]
      case "all":
        return [.airports, .navaids, .flightServiceStations, .ARTCCFacilities]
      default:
        return [.airports, .navaids, .flightServiceStations, .ARTCCFacilities]
    }
  }

  private func printRecordCounts(nasr: NASR, format: String) async {
    print("\n  \(format) Record Counts:")
    if let airports = await nasr.data.airports {
      print("    Airports: \(airports.count)")
    }
    if let navaids = await nasr.data.navaids {
      print("    Navaids: \(navaids.count)")
    }
    if let fsses = await nasr.data.FSSes {
      print("    FSSes: \(fsses.count)")
    }
    if let artccs = await nasr.data.ARTCCs {
      print("    ARTCCs: \(artccs.count)")
    }
  }

  private func printComparison(txt: TimingResult, csv: TimingResult) {
    print("\n" + String(repeating: "=", count: 80))
    print("PERFORMANCE COMPARISON")
    print(String(repeating: "=", count: 80))

    txt.printSummary()
    csv.printSummary()

    print("\n" + String(repeating: "-", count: 80))
    print("Relative Performance (CSV vs TXT):")

    if txt.downloadTime > 0 && csv.downloadTime > 0 {
      let downloadRatio = csv.downloadTime / txt.downloadTime
      print(
        "  Download: \(String(format: "%.1fx", downloadRatio)) \(downloadRatio < 1 ? "faster" : "slower")"
      )
    }

    let loadRatio = csv.loadTime / txt.loadTime
    print("  Load: \(String(format: "%.1fx", loadRatio)) \(loadRatio < 1 ? "faster" : "slower")")

    let parseRatio = csv.parseTime / txt.parseTime
    print("  Parse: \(String(format: "%.1fx", parseRatio)) \(parseRatio < 1 ? "faster" : "slower")")

    let totalRatio = csv.totalTime / txt.totalTime
    print("  Total: \(String(format: "%.1fx", totalRatio)) \(totalRatio < 1 ? "faster" : "slower")")

    print("\n" + String(repeating: "=", count: 80))

    // Summary
    if totalRatio < 1 {
      let improvement = (1 - totalRatio) * 100
      print("✅ CSV format is \(String(format: "%.1f%%", improvement)) faster overall")
    } else {
      let degradation = (totalRatio - 1) * 100
      print("⚠️  TXT format is \(String(format: "%.1f%%", degradation)) faster overall")
    }
  }
}
