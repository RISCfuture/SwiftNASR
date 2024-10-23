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

* ``NASR/fromInternetToMemory(activeAt:)``,
* ``NASR/fromInternetToFile(_:activeAt:)``,
* ``NASR/fromLocalArchive(_:)``, and
* ``NASR/fromLocalDirectory(_:)``.

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

- ``NASR/fromInternetToMemory(activeAt:)``
- ``ArchiveDataDistribution``
- ``NASR/fromInternetToFile(_:activeAt:)``
- ``ArchiveFileDistribution``

### Loading Distributions from Disk

- ``NASR/fromLocalArchive(_:)``
- ``ArchiveFileDistribution``
- ``NASR/fromLocalDirectory(_:)``
- ``DirectoryDistribution``

### Loading Parsed Data

- ``NASR/fromData(_:)``
- ``NullDistribution`` 

### Subclassing

- ``Distribution``
