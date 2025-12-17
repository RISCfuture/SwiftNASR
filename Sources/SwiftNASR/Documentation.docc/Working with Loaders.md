# Working with Loaders

Subclasses of ``Loader`` load NASR distributions, either from disk or from the
FADDS website. Loaders are responsible for loading the raw data and wrapping it
in a corresponding ``Distribution`` instance, which will handle parsing the
data.

## Overview

Classes that implement ``Loader`` are responsible for loading NASR data, either
from disk, memory, or the Internet. Subclasses of ``Downloader`` are responsible
for loading NASR data from the Internet. You would choose a subclass of
``Loader`` or ``Downloader`` depending on how you want your data downloaded:

* ``ArchiveLoader`` to load an existing NASR archive on-disk in ZIP format,
* ``DirectoryLoader`` to load an existing NASR directory on-disk, after being
  unzipped,
* ``ArchiveDataDownloader`` to download a distribution to memory, or
* ``ArchiveFileDownloader`` to download a distribution to disk.

You would then use a corresponding ``Distribution`` subclass to process the
downloaded data. Each type of ``Loader`` works with a corresponding
``Distribution`` type that it returns.

There is one other Loader subclass, ``NullLoader``, which generates
``NullDistribution``s. This Loader is used when reloading already-parsed data
that was stored using a `Coder` (using ``NASR/fromData(_:)``). Because there is
no need to re-parse the data, ``NullLoader`` is used as a stand-in for an actual
loader.

Normally you do not need to instantiate your own ``Loader`` or ``Distribution``
objects. This is done automatically by the following methods on ``NASR``:

* ``NASR/fromInternetToMemory(activeAt:format:)``,
* ``NASR/fromInternetToFile(_:activeAt:format:)``,
* ``NASR/fromLocalArchive(_:format:)``, and
* ``NASR/fromLocalDirectory(_:format:)``.

You can, however, provide your own ``Loader`` subclass to ``NASR`` if you
need to customize distribution downloading behavior, using
``NASR/init(loader:)``.

## Creating your own Loader subclass

If needed, you can create your own ``Loader`` subclass to parse NASR
distributions in a nonstandard format. See the ``Loader`` and ``Downloader``
docuemntation for more information.

## Topics

### Downloading Distributions

- ``NASR/fromInternetToMemory(activeAt:format:)``
- ``ArchiveDataDistribution``
- ``NASR/fromInternetToFile(_:activeAt:format:)``
- ``ArchiveFileDistribution``

### Loading Distributions from Disk

- ``NASR/fromLocalArchive(_:format:)``
- ``ArchiveFileDistribution``
- ``NASR/fromLocalDirectory(_:format:)``
- ``DirectoryDistribution``

### Subclassing

- ``Loader``
- ``Downloader``
