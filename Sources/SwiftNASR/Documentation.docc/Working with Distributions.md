# Working with Distributions

Distributions are the files that contain the NASR data, as downloaded from the
FADDS website. You can use subclasses of ``Distribution`` to automatically
download those files, or work with previously-downloaded files.

## Overview

Subclasses of the ``Loader`` superclass are used to load distributions
from memory, disk, or the FADDS website (see <doc:Working-with-Loaders>). The
``Distribution`` protocol describes those classes intended for processing
downloaded distributions data from the FADDS website. You would choose a
subclass of ``Distribution`` depending on how your data is stored:

* ``ArchiveDataDistribution`` if your distribution is stored in-memory in ZIP
  format (from ``ArchiveDataDownloader``),
* ``ArchiveFileDistribution`` if your distribution is stored on-disk in ZIP
  format (from ``ArchiveFileDownloader``), or
* ``DirectoryDistribution`` if your distribution is stored on-disk in an
  unzipped directory structure.

Normally you do not need to instantiate your own ``Downloader`` or
``Distribution`` objects. This is done automatically by the following methods on
``NASR``:

* ``NASR/fromInternetToMemory(activeAt:format:)``,
* ``NASR/fromInternetToFile(_:activeAt:format:)``,
* ``NASR/fromLocalArchive(_:)``, and
* ``NASR/fromLocalDirectory(_:format:)``.

## Data Formats

The FAA distributes NASR data in two formats, represented by ``DataFormat``:

* **TXT (Fixed-Width)**: The traditional format where each field occupies a
  fixed number of characters. This format has been available for many years and
  is fully supported.
* **CSV (Comma-Separated Values)**: A newer format where fields are separated
  by commas. This format is more compact but may have slightly different field
  availability.

Specify the format when loading a distribution:

```swift
// Load CSV format from the internet
let nasr = NASR.fromInternetToMemory(format: .csv)

// Load TXT format from a local directory (default)
let nasr = NASR.fromLocalDirectory(myURL, format: .txt)
```

CSV format currently supports parsing airports, ARTCCs, FSSs, and navaids.

You can, however, provide your own ``Distribution`` subclass to ``NASR`` if you
need to customize distribution parsing behavior.

There is one additional subclass of ``Distribution``, called
``NullDistribution``. This subclass is associated with the ``NASR/fromData(_:)``
method. It is used for data that was previously parsed by a different
distribution, and is now being reloaded into memory (e.g., after being stored by
a `Coder`).

## Creating your own Distribution subclass

If needed, you can create your own ``Distribution`` subclass to parse NASR
distributions in a nonstandard format. See the ``Distribution`` docuemntation
for more information.

## Topics

### Downloading Distributions

- ``NASR/fromInternetToMemory(activeAt:format:)``
- ``ArchiveDataDistribution``
- ``NASR/fromInternetToFile(_:activeAt:format:)``
- ``ArchiveFileDistribution``

### Loading Distributions from Disk

- ``NASR/fromLocalArchive(_:)``
- ``ArchiveFileDistribution``
- ``NASR/fromLocalDirectory(_:format:)``
- ``DirectoryDistribution``

### Loading Parsed Data

- ``NASR/fromData(_:)``
- ``NullDistribution`` 

### Subclassing

- ``Distribution``
