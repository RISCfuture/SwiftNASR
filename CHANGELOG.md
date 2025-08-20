# Change Log

## [1.0.0] - 2025-08-20

Swift 6 concurrency mode

### API Changes

* Removes Combine and callback concurrency models in favor of exclusively
  `async`/`await`
  * Removes `ConcurrentDistribution` protocol (now redundant)
  * Marks loaders and distribution classes as `final` and `Sendable`
  * Adds `FileReadActor` to control synchronous access to a distribution's files
* Converts record types (airport, navaid, etc.) into structs for concurrency
  guarantees
  * Adds `Record` and `ParentRecord` protocols describing parsed records
  * Makes record types `Sendable` and `Codable`
  * Makes parent record types `Hashable`, `Equatable`, and `Identifiable`
* Converts `NASR` and `NASRData` to actors
  * Adds `NASRDataCodable` to preserve `Codable` support for `NASRData`
* Advances minimum OS versions

### Documentation Changes

* Updates documentation
  * NOTE: A current bug in Swift-DocC is preventing some articles from showing
    in the sidebar

### Test Changes

* Updates tests to use async model
* Rewrites the E2E test app

## [0.3.0] - 2024-09-24

Updated Swift Tools version to 6.0 (stil using language version 5).

### Breaking Changes

* `ARTCC`: ICAO ID is now optional.

### API Changes

* ISO-Latin1 encoding is used when parsing distribution text files.
* Moved from `NSLocalizedString` to string catalogs.
* `Runway`: Added a gradient estimation method that uses the base and reciprocal
  elevations (when known). You can use this is a stopgap until the FAA resumes
  distributing runway gradient data.
* Dependency updates.

## [0.2.0] - 2024-05-16

Updated ZIPFoundation dependency.

### Breaking Changes

* The `ArchiveFileDistribution` and `ArchiveDataDistribution` initializers no
  longer return `nil` if the archive could not be read; instead, they rethrow
  the error thrown by ZIPFoundation.
* The `ArchiveFileDownloader` and `ArchiveDataDownloader`'s `load` methods no
  longer throw `Error.badData`; instead they rethrow the error thrown by
  ZIPFoundation.

### API Changes

## [0.1.0] - 2024-04-03

Initial pre-release (Airport, ARTCC, FSS, and Navaid parsing).
