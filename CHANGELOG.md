# Change Log

## [Unreleased]

## [4.3.0] - 2026-09-16

### Added

- `Runway.PavementClassification.ratingSystem` distinguishes a PCR value from a PCN one. The FAA added a leading rating-system code to the `PAVEMENT CLASSIFICATION` field (`PCN/103 /R/C/W/T`, `PCR/2110/F/B/X/T`) as part of the ICAO ACR/PCR transition. The two are separate scales — the 2026-10-01 cycle carries 1,101 PCR values against 1,007 PCN — so a consumer must know which it holds before comparing it against an aircraft's ACR or ACN
- `Airway.Segment.isMEAUnusable` exposes the MEA gap indicator that AWY1 gained at column 308 (`U` unusable, `N` not), also carried by the CSV `MEA_GAP` column
- `Airway.Segment.requiredNavigationPerformanceNM` exposes the RNP value, alongside `Airway.Segment.requiredNavigationPerformance` as a `Measurement<UnitLength>`. The fixed-width parser already transformed the field but never read it into the model, and the CSV `REQD_NAV_PERFORMANCE` column was not read at all

### Changed

- **BREAKING:** `Runway.PavementClassification` gained a non-optional `ratingSystem`, so a `NASRData` archive serialized by an earlier version no longer decodes if any runway carried a pavement classification

### Fixed

- Airways parsed from the TXT distribution no longer collapse to a single record. `awy_rf.txt` effective 2026-09-03 describes 44 fields against the parser's 43, having inserted the MEA gap indicator before the record sort sequence, so every AWY1 record failed the field-count check and the only airway left was one recovered from a remark record. The 2026-09-03 cycle yields 1,230 airways
- Weather stations parsed from the TXT distribution are no longer lost entirely. The AWOS1 transformations declared 19 fields, but `awos_rf.txt` ends with a filler line carrying no justification or type column, which describes no field the layout parser can slice; the resulting count mismatch dropped all 2,665 records and orphaned their 257 remarks
- A runway's pavement classification is parsed again, in both distribution formats. The field now holds six slash-separated components rather than five, so every TXT runway carrying pavement data was dropped — which in turn orphaned the remark and attendance records referencing those runways — while the CSV column was renamed `PCN` to `PCN_PCR_NUMBER`, and because an absent CSV column reads as `nil`, all 23,174 runways silently lost their pavement data without reporting anything
- ATS airways designated `SP` (special route) are parsed. `ats_rf.txt` documents a fifth designation that the parser did not recognize, dropping 290 ATS1 records and orphaning their point descriptions
- Navaid class codes `L` and `M` are recognized. They are absent from `nav_rf.txt` but appear in production data on Canadian NDBs and, combined as `LFM`, on fan markers
- A runway, remark, arresting system, or attendance schedule naming a site number with no airport record is reported as `unknownParentRecord` through the parse error handler. The fixed-width airport parser skipped these silently, so a dropped `APT` record took its child records with it without anything saying so; the other eleven fixed-width parsers already reported the same condition
- The record names in an `unknownParentRecord` error are localized. Both the child and the parent kind were interpolated into the description as English string literals, so a translated sentence would have come out half in English; each is now a case with its own localized text
- An airport or runway parsed from the TXT distribution whose federal agreements, runway surface, or pavement classification holds an unrepresentable value is kept, with a `fieldError` naming the field, rather than dropped whole. This matches what the CSV parsers already did: in the 2026-09-03 cycle a stray slash in one airport's NASP code cost that airport entirely (19,410 TXT airports against 19,411 in CSV), and a heliport whose surface reads `OR` — apparently its own state code, miskeyed — cost that runway

## [4.2.0] - 2026-09-14

### Changed

- `FoundationNetworking` is re-exported from the downloader API on platforms that have it. The archive downloaders' `session` properties and `Error.badResponse` are spelled in terms of `URLSession` and `URLResponse`, which live in `FoundationNetworking` rather than `Foundation` on Linux; consumers touching either no longer need their own `import FoundationNetworking` to name those types
- `Airport.id` is documented as unique within a single NASR cycle rather than stable across cycles. The FAA re-keyed FAA LID `18AL` (LOUISVILLE STAGEFIELD AHP) from site number `03329.19` to `00329.19` in the 2026-09-03 cycle, so persisting either the site number or the LID across cycles requires a reconciliation step

### Fixed

- A runway's Pavement Classification field no longer crashes the fixed-width airport parser when it does not hold a five-part PCN value. The field is widening from 11 to 16 characters for the ICAO PCR transition, and a PCR value is conventionally four-part rather than PCN's `number/type/subgrade/tirePressure/determination`; splitting such a value and indexing the missing components trapped on an out-of-range index, which the parser's own `do`/`catch` could not intercept. Any value that does not yield exactly five components is now reported as an `invalidValue` field error, so the record is diagnosed and skipped instead of killing the process
- A layout whose field count disagrees with a parser's compiled-in field transformations is now reported as an error rather than trapping (a layout with an extra field) or silently reading each subsequent value from its neighbouring field (a layout with one fewer)
- A download that comes back over a non-HTTP protocol now throws `Error.badResponse` as intended. Both archive downloaders force-cast the response to `HTTPURLResponse` inside the `else` branch of the `as?` test that had just failed, so any response that was not an `HTTPURLResponse` trapped instead of surfacing the error describing it

## [4.1.1] - 2026-09-02

### Fixed

- A layout that declares more bytes than its records contain no longer crashes the fixed-width parsers. The airport layout effective 2026-09-03 widens the runway record's Pavement Classification field from 11 to 16 characters for the ICAO PCR transition, shifting the trailing filler to byte 1536 while the records themselves remain 1532 bytes; slicing that filler trapped on an out-of-range index and killed the process. Only a layout's final field may now overrun, and it is clamped to the end of the record. Any earlier field that runs past the end reports `truncatedRecord` through the parse error handler, so a genuinely short record is still diagnosed rather than silently truncated
- A record shorter than its own record-type identifier now reports `truncatedRecord` instead of trapping

## [4.1.0] - 2026-07-06

### Added

- Linux support. `URLSession` is guarded behind `FoundationNetworking`, a
  `String(localized:)` shim covers error strings, the archive downloaders fall
  back to buffered responses on Linux, and several platform-portability fixes
  were applied (`@objc` gating, `ProcessInfo`, `URLProtocol` initializer, and
  file-system error-code differences). Apple platforms are unaffected.

## [4.0.0] - 2026-06-26

### Added

- Coded Departure Routes are now parsed from the TXT distribution (`CDR.txt`) in addition to CSV; the six fields present only in the CSV file are `nil` when parsed from TXT
- The CSV `TerminalCommFacility` now carries radar, military-operations, and class-airspace data, folded in from the `RDR`, `MIL_OPS`, and `CLS_ARSP` files that the FAA split out of the legacy `TWR` subscriber file — matching the TXT representation

### Changed

- **BREAKING:** `JSONZipEncoder` and `JSONZipDecoder` are now `Sendable` value types (`struct`) instead of `JSONEncoder`/`JSONDecoder` subclasses, eliminating their unsound `@unchecked Sendable` conformances. Set formatting via `JSONZipEncoder(outputFormatting:)` (the `outputFormatting` property remains available); both types can now be shared safely across concurrency domains
- Progress reporting is now updated synchronously and in order. The downloader's GCD `DispatchQueue.main.async` hop and the per-chunk `Task { @MainActor in … }` hops in the archive and directory distributions were replaced with direct, thread-safe `Progress` mutation, removing a hazard where progress could be reported out of order or after a stream finished
- Adopted the Approachable Concurrency upcoming-feature flags (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`), which changes the execution semantics of `nonisolated` async work
- **BREAKING:** Raised the minimum deployment targets to macOS 15, iOS 18, tvOS 18, watchOS 11, and visionOS 2 to adopt the standard-library `Synchronization` module (`Mutex`/`Atomic`)

### Internal

- Replaced `nonisolated(unsafe)` statics in the test URL-protocol mock with a `Synchronization.Mutex`, and modernized the manual smoke-test harness to top-level `await`

## [3.0.0] - 2026-06-03

### Breaking Changes

- `NASR.parse` now takes `errorHandler: (RecordParseError) -> ParseDisposition` instead of `(Error) -> Bool`, unifying dropped-record and kept-field diagnostics into a single channel

### Added

- `RecordParseError` and `ParseDisposition` public types describing parse problems and how to respond to them
- Parsers now surface unrepresentable values as field- or record-level diagnostics instead of silently coercing them to `nil`

### Fixed

- A single malformed row in a CSV file no longer drops the rest of that file's rows
- Many enum and value gaps now parse correctly via CSV synonyms (airway point types, fuel types, ILS marker and back-course status, hold facility routing, terminal facility types)
- Corrected comma- and slash-separated field splitting (fuel types, runway surfaces)
- AWOS weather stations without coordinates are kept (with a nil position) instead of dropped
- Fixed two latent parser bugs: a weather-station parser that could abort an entire file on one bad row, and a string-splitting helper that emitted separator characters

## [2.0.1] - 2026-06-03

### Fixed

- Fixed silent record and field drops discovered by validating the parsers against live FAA data

## [2.0.0] - 2026-05-01

### Breaking Changes

- Renamed date-component-returning fields to `…components` accessors; canonical `Date`-returning extensions are now provided alongside under the un-suffixed name
- Dimensional property and variable names are now suffixed with their unit of measure (e.g. `altitude` → `altitudeFeet`)
- Glidepath in CSV format is now stored in degrees rather than 100ths of a degree

### Added

- CSV parsing support, with parsers for all remaining record types
- Complete coverage of all TXT and CSV model types and their parsers
- `Measurement` extensions for dimensional properties
- `Date`-returning extensions accompanying the renamed `components` accessors
- `--record-types` option for `SwiftNASR_E2E`
- Improved CSV progress tracking; E2E tests split into separate files
- `LosslessStringConvertible` conformance for canonical representations

### Changed

- Replaced `FixedWidthParser` with the more performant `ByteParser`
- Normalized the `Cycle` interface for consistency across libraries
- Adopted more typesafe parsing throughout
- Concurrency improvements and warning fixes

### Internal

- Updated to Swift 6.2; CI matrix standardized to Swift 6.0–6.2 on macOS 14–15
- Added swift-format
- Updated GitHub Actions
- Updated documentation generation and READMEs

## [1.0.0] - 2025-08-20

Swift 6 concurrency mode

### API Changes

- Removes Combine and callback concurrency models in favor of exclusively
  `async`/`await`
  - Removes `ConcurrentDistribution` protocol (now redundant)
  - Marks loaders and distribution classes as `final` and `Sendable`
  - Adds `FileReadActor` to control synchronous access to a distribution's files
- Converts record types (airport, navaid, etc.) into structs for concurrency
  guarantees
  - Adds `Record` and `ParentRecord` protocols describing parsed records
  - Makes record types `Sendable` and `Codable`
  - Makes parent record types `Hashable`, `Equatable`, and `Identifiable`
- Converts `NASR` and `NASRData` to actors
  - Adds `NASRDataCodable` to preserve `Codable` support for `NASRData`
- Advances minimum OS versions

### Documentation Changes

- Updates documentation
  - NOTE: A current bug in Swift-DocC is preventing some articles from showing
    in the sidebar

### Test Changes

- Updates tests to use async model
- Rewrites the E2E test app

## [0.3.0] - 2024-09-24

Updated Swift Tools version to 6.0 (stil using language version 5).

### Breaking Changes

- `ARTCC`: ICAO ID is now optional.

### API Changes

- ISO-Latin1 encoding is used when parsing distribution text files.
- Moved from `NSLocalizedString` to string catalogs.
- `Runway`: Added a gradient estimation method that uses the base and reciprocal
  elevations (when known). You can use this is a stopgap until the FAA resumes
  distributing runway gradient data.
- Dependency updates.

## [0.2.0] - 2024-05-16

Updated ZIPFoundation dependency.

### Breaking Changes

- The `ArchiveFileDistribution` and `ArchiveDataDistribution` initializers no
  longer return `nil` if the archive could not be read; instead, they rethrow
  the error thrown by ZIPFoundation.
- The `ArchiveFileDownloader` and `ArchiveDataDownloader`'s `load` methods no
  longer throw `Error.badData`; instead they rethrow the error thrown by
  ZIPFoundation.

### API Changes

## [0.1.0] - 2024-04-03

Initial pre-release (Airport, ARTCC, FSS, and Navaid parsing).
