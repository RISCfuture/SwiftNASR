# ``SwiftNASR/Downloader``

A downloader is a class that can download a NASR distribution from the FAA's
website. This abstract superclass contains functionality common to all
downloaders.

Normally you do not work with `Downloader` subclasses directly; they are
automatically instantiated for you by ``NASR``'s loading methods.

## Subclassing Downloader

A `Downloader` is instantiated with a ``Cycle`` (``init(cycle:)``) to download.
From that cycle, the `Downloader` can generate a ``cycleURL``. When one of the
`load` methods is called, the data is downloaded to the appropriate destination,
and a subclass of ``Distribution`` is generated to process that data.

## Topics

### Subclasses

- ``ArchiveDataDownloader``
- ``ArchiveFileDownloader``

### Creating Downloaders

- ``init(cycle:)``

### Cycles

- ``cycle``
- ``cycleURL``

### Downloading Distributions

- ``load(withProgress:)``
