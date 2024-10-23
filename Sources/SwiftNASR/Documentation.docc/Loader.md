# ``SwiftNASR/Loader``

Loaders create a `Distribution` from a NASR archive, on disk, in memory, or
downloaded from the Internet (see `Downloader`).. For example,
`ArchiveDataDownloader` produces a ZIP-compressed archive, and so the
data would need to be handled by `ArchiveDataDistribution`. The `ArchiveLoader`
implementation mediates between the two classes.

Normally you do not work with `Loader` subclasses directly; they are
automatically instantiated for you by ``NASR``'s loading methods.

## Implementing Loader

Types of the `Loader` protocol need only implement the three `load` methods,
each of which returns a ``Distribution`` instance that wraps the data from the
loader. The ``Distribution`` is responsible for parsing the data; the `Loader`
only retrieves it from disk, memory, or the Internet.

## Topics

### Subclasses

- ``ArchiveLoader``
- ``DirectoryLoader``
- ``Downloader``
- ``NullLoader``

### Loading Data

- ``load(withProgress:)``
