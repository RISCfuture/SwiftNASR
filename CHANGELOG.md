# Change Log

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
