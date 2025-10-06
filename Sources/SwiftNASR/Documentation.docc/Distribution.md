# ``SwiftNASR/Distribution``

`Distribution` is a protocol that describes classes that can load NASR data from
different ways of storing distribution data.

Normally you do not work with `Distribution` subclasses directly; they are
automatically instantiated for you by ``NASR``'s loading methods.

## Data Formats

Distributions support two data formats, specified by ``DataFormat``:

- **TXT (Fixed-Width)**: The traditional format where each field occupies a
  fixed number of characters. This is the default format.
- **CSV (Comma-Separated Values)**: A newer format where fields are separated
  by commas.

The format is determined when loading a distribution and affects which parsers
are used. See ``DataFormat`` for more information.

## Subclassing Distribution

The existing subclasses of `Distribution` process NASR data downloaded from
FADDS, in both zipped and unzipped formats. If you wish to process NASR data
distributed in a different format, you should subclass `Distribution`.

Note that this is separate from wanting to store and retrieve NASR data already
parsed by a `Distribution`. If you have already-parsed data that you wish to
store and retrieve later, simply use a `Coder`. See ``NASRDataCodable`` for more
information.

## Topics

### Subclasses

- ``ArchiveDataDistribution``
- ``ArchiveFileDistribution``
- ``DirectoryDistribution``
- ``NullDistribution``

### Data Format

- ``DataFormat``
- ``format``

### Locating a File

- ``findFile(prefix:)``

### Reading a File

- ``readFile(path:withProgress:returningLines:)``

### Reading Records

These methods are already implemented and normally do not need to be overridden.

- ``RecordType``
- ``read(type:withProgress:returningLines:)``

### Reading the Cycle

These methods are already implemented and normally do not need to be overridden.

- ``readCycle()``
