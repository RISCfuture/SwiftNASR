# Change Log

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
