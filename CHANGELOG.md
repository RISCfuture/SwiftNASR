# Change Log

## [3.1.0] - 2026-06-04

### Added

- Coded Departure Routes are now parsed from the TXT distribution (`CDR.txt`) in addition to CSV; the six fields present only in the CSV file are `nil` when parsed from TXT
- The CSV `TerminalCommFacility` now carries radar, military-operations, and class-airspace data, folded in from the `RDR`, `MIL_OPS`, and `CLS_ARSP` files that the FAA split out of the legacy `TWR` subscriber file — matching the TXT representation

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
