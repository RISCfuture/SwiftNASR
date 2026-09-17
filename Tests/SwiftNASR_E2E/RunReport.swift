import Foundation
import SwiftNASR

/// How many sample messages of each kind are kept per record type.
let defaultErrorSampleLimit = 3

/// The machine-readable result of one end-to-end run.
struct RunReport: Codable, Sendable {
  /// Bumped when a field changes meaning, so a consumer can refuse a report it cannot read.
  static let currentSchemaVersion = 1

  let schemaVersion: Int
  /// The cycle the run targeted, as `YYYY-MM-DD`.
  let cycle: String
  let finishedAt: Date
  /// The record types the run was narrowed to, or `nil` when every type ran. Counts from a
  /// filtered run are not comparable with counts from a full one.
  let recordTypeFilter: [String]?
  let failed: Bool
  let failureReasons: [String]
  /// Keyed by lowercased format name.
  let formats: [String: FormatReport]
  let errorSamples: [ErrorSample]
  let drift: [DriftFinding]

  init(
    cycle: Cycle,
    recordTypeFilter: Set<RecordType>?,
    formats: [FormatReport],
    errorSamples: [ErrorSample],
    drift: [DriftFinding]
  ) {
    schemaVersion = Self.currentSchemaVersion
    self.cycle = cycle.description
    finishedAt = Date()
    self.recordTypeFilter = recordTypeFilter.map { $0.map(\.rawValue).sorted() }
    self.formats = Dictionary(
      uniqueKeysWithValues: formats.map { ($0.format.lowercased(), $0) }
    )
    failureReasons = formats.flatMap { report in
      report.failureReasons.map { "\(report.format): \($0)" }
    }
    failed = !failureReasons.isEmpty
    self.errorSamples = errorSamples
    self.drift = drift
  }

  /// Reads a report written by an earlier run, for use as a drift baseline.
  static func read(from url: URL) throws -> Self {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(Self.self, from: Data(contentsOf: url))
  }

  /// Writes the report as JSON, creating missing intermediate directories.
  func write(to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(self).write(to: url)
  }
}

/// One format's results.
struct FormatReport: Codable, Sendable {
  let format: String
  /// The cycle the loaded distribution declares, where it could be read.
  let distributionCycle: String?
  /// What ended this format's run before anything could be verified.
  let abortReason: String?
  let saveError: String?
  let durationSeconds: Int
  let failed: Bool
  let failureReasons: [String]
  /// Keyed by record type code, e.g. `APT`.
  let recordTypes: [String: RecordTypeReport]
  let associations: AssociationReport

  init(
    format: DataFormat,
    expectedCycle: Cycle?,
    distributionCycle: Cycle?,
    abortReason: String?,
    saveError: String?,
    durationSeconds: Int,
    recordTypes: [String: RecordTypeReport],
    associations: AssociationReport,
    baseline: Self?
  ) {
    self.format = format.rawValue
    self.distributionCycle = distributionCycle?.description
    self.abortReason = abortReason
    self.saveError = saveError
    self.durationSeconds = durationSeconds
    self.recordTypes = recordTypes
    self.associations = associations

    var reasons: [String] = []
    if let abortReason { reasons.append(abortReason) }
    if let expectedCycle, let distributionCycle, expectedCycle != distributionCycle {
      reasons.append("the archive declares cycle \(distributionCycle), not \(expectedCycle)")
    }
    let missing = recordTypes.filter { $0.value.count == nil }.keys.sorted()
    if !missing.isEmpty {
      reasons.append("did not parse: \(missing.joined(separator: ", "))")
    }
    if let reason = Self.droppedRecordFailure(in: recordTypes, against: baseline) {
      reasons.append(reason)
    }
    if !associations.failures.isEmpty {
      reasons.append(
        "association checks failed: \(associations.failures.joined(separator: ", "))"
      )
    }
    if let saveError { reasons.append("could not save: \(saveError)") }
    failureReasons = reasons
    failed = !reasons.isEmpty
  }
}

extension FormatReport {
  /// Dropped records are only a failure when they are new.
  ///
  /// Every cycle drops the same handful of records to FAA data that is genuinely malformed — the
  /// CSV terminal comm facility records naming facilities the distribution does not contain — so
  /// failing on a nonzero count would file an issue every cycle and the alert would stop meaning
  /// anything. Against an earlier run, only an increase is reported; with nothing to compare
  /// against, any dropped record is.
  fileprivate static func droppedRecordFailure(
    in recordTypes: [String: RecordTypeReport],
    against baseline: FormatReport?
  ) -> String? {
    guard let baseline else {
      let dropped = recordTypes.values.reduce(0) { $0 + $1.droppedErrors }
      guard dropped > 0 else { return nil }
      return "\(dropped) dropped record\(dropped == 1 ? "" : "s")"
    }

    let risen = recordTypes.compactMap { recordType, report -> String? in
      let was = baseline.recordTypes[recordType]?.droppedErrors ?? 0
      guard report.droppedErrors > was else { return nil }
      return "\(recordType) \(was) -> \(report.droppedErrors)"
    }
    guard !risen.isEmpty else { return nil }
    return "dropped records rose: \(risen.sorted().joined(separator: ", "))"
  }
}

/// One record type's count and error tally.
struct RecordTypeReport: Codable, Sendable {
  let displayName: String
  /// How many records parsed, or `nil` when the record type parsed to nothing at all.
  let count: Int?
  let droppedErrors: Int
  let fieldErrors: Int

  init(displayName: String, count: Int?, tally: ErrorTally) {
    self.displayName = displayName
    self.count = count
    droppedErrors = tally.droppedRecordCount
    fieldErrors = tally.fieldErrorCount
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    displayName = try container.decode(String.self, forKey: .displayName)
    count = try container.decodeIfPresent(Int.self, forKey: .count)
    droppedErrors = try container.decode(Int.self, forKey: .droppedErrors)
    fieldErrors = try container.decode(Int.self, forKey: .fieldErrors)
  }

  /// `count` is written explicitly so a record type that parsed to nothing appears as `null`
  /// rather than vanishing, which is how a consumer tells it apart from a type the run skipped.
  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(displayName, forKey: .displayName)
    try container.encode(count, forKey: .count)
    try container.encode(droppedErrors, forKey: .droppedErrors)
    try container.encode(fieldErrors, forKey: .fieldErrors)
  }

  private enum CodingKeys: String, CodingKey {
    case displayName, count, droppedErrors, fieldErrors
  }
}

/// The association checks' outcome.
struct AssociationReport: Codable, Sendable {
  /// A format whose run ended before associations could be checked.
  static let notRun = Self(passedCount: 0, failures: [])

  let passedCount: Int
  let failures: [String]
}

/// One error message kept for a human reading the report.
struct ErrorSample: Codable, Sendable {
  let format: String
  let recordType: String
  let kind: Kind
  let message: String

  enum Kind: String, Codable, Sendable {
    case dropped, field
  }
}

/// A record type whose count moved enough between cycles to be worth a look.
struct DriftFinding: Codable, Sendable {
  let format: String
  let recordType: String
  let was: Int
  let now: Int?
  let delta: Int?
  let reason: Reason

  enum Reason: String, Codable, Sendable {
    /// The count was positive and is now zero.
    case zeroed
    /// The record type is absent from this run entirely.
    case disappeared
    /// The count moved past both thresholds.
    case moved
  }
}

// MARK: - Building

/// Pairs each record type's count with its error tally.
func recordTypeReports(
  of nasr: NASR,
  recordTypes: Set<RecordType>,
  tallies: [RecordType: ErrorTally]
) async -> [String: RecordTypeReport] {
  var reports: [String: RecordTypeReport] = [:]
  for recordType in recordTypes {
    let displayName = recordTypeRegistry[recordType]?.displayName ?? String(describing: recordType)
    reports[recordType.rawValue] = await RecordTypeReport(
      displayName: displayName,
      count: getRecordCount(from: nasr.data, for: recordType),
      tally: tallies[recordType] ?? ErrorTally()
    )
  }
  return reports
}

/// Flattens the retained samples into the report's error list.
func errorSamples(format: DataFormat, tallies: [RecordType: ErrorTally]) -> [ErrorSample] {
  tallies.keys.sorted { $0.rawValue < $1.rawValue }.flatMap { recordType -> [ErrorSample] in
    let tally = tallies[recordType]!
    let dropped = tally.droppedRecordSamples.map { message in
      ErrorSample(
        format: format.rawValue,
        recordType: recordType.rawValue,
        kind: .dropped,
        message: message
      )
    }
    let fields = tally.fieldErrorSamples.map { message in
      ErrorSample(
        format: format.rawValue,
        recordType: recordType.rawValue,
        kind: .field,
        message: message
      )
    }
    return dropped + fields
  }
}

/// Compares this run's record counts against an earlier run's.
///
/// Only the baseline's record types are walked: a type present now but absent from the baseline is
/// what a previous run whose CSV leg died looks like, not drift.
func driftFindings(
  from baseline: RunReport,
  to formats: [FormatReport],
  percent: Int,
  minimum: Int
) -> [DriftFinding] {
  let current = Dictionary(uniqueKeysWithValues: formats.map { ($0.format.lowercased(), $0) })

  return baseline.formats.sorted { $0.key < $1.key }.flatMap { formatKey, baseFormat in
    guard let currentFormat = current[formatKey] else { return [DriftFinding]() }

    return baseFormat.recordTypes.sorted { $0.key < $1.key }
      .compactMap { recordType, baseType -> DriftFinding? in
        guard let was = baseType.count else { return nil }
        func finding(now: Int?, delta: Int?, reason: DriftFinding.Reason) -> DriftFinding {
          .init(
            format: formatKey,
            recordType: recordType,
            was: was,
            now: now,
            delta: delta,
            reason: reason
          )
        }

        guard let now = currentFormat.recordTypes[recordType]?.count else {
          return finding(now: nil, delta: nil, reason: .disappeared)
        }
        if was > 0, now == 0 {
          return finding(now: now, delta: now - was, reason: .zeroed)
        }
        let delta = now - was
        guard abs(delta) >= minimum, abs(delta) * 100 > percent * was else { return nil }
        return finding(now: now, delta: delta, reason: .moved)
      }
  }
}

// MARK: - Console output

extension RunReport {
  func printSummary() {
    for key in formats.keys.sorted() {
      formats[key]!.printSummary(samples: errorSamples.filter { $0.format.lowercased() == key })
    }

    if !drift.isEmpty {
      print("\n=== Record Count Drift ===")
      for finding in drift {
        let now = finding.now.map(String.init) ?? "missing"
        print("  - \(finding.format.uppercased()) \(finding.recordType): \(finding.was) -> \(now)")
      }
    }

    print("")
    if failed {
      print("FAILED: cycle \(cycle)")
      for reason in failureReasons { print("  - \(reason)") }
    } else {
      print("Cycle \(cycle) checked out.")
    }
  }
}

extension FormatReport {
  fileprivate func printSummary(samples: [ErrorSample]) {
    print("\n=== \(format) ===")
    if let abortReason {
      print("Run aborted: \(abortReason)")
      return
    }

    for key in recordTypes.keys.sorted() {
      let report = recordTypes[key]!
      let count = report.count.map(String.init) ?? "did not parse"
      print("  \(report.displayName): \(count)")
    }

    let dropped = recordTypes.values.reduce(0) { $0 + $1.droppedErrors }
    let fields = recordTypes.values.reduce(0) { $0 + $1.fieldErrors }
    print("Errors: \(dropped) dropped record(s), \(fields) unrepresentable field(s)")
    for sample in samples { print("  - \(sample.message)") }

    print("Associations passed: \(associations.passedCount)")
    for failure in associations.failures { print("  - failed: \(failure)") }
  }
}
