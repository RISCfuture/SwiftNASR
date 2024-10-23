# Records

SwiftNASR records represent the data types present in a NASR distribution.
After one of the `load` methods is called (see _Loaders_), records can be
parsed.

Records are stored in a ``NASRData`` instance after being loaded by the
``NASR/parse(_:withProgress:errorHandler:)`` method.

Each record maintains an internal link back to its parent ``NASRData`` object.
This is used to allow records to cross-reference each other; e.g., the
``Airport/tieInFSS`` method links to an ``FSS`` object, but only if the FSS
records have been loaded with a prior `load` call:

``` swift
let data: NASRData // previously initialized
await data.parse(.airports)
await data.airports[0].tieInFSS // will always be nil since FSSes have not been loaded
await data.parse(.flightServiceStations)
await data.airports[0].tieInFSS // will not be nil if present in the distribution data
```

(Note that since `NASRData` is an actor, you need to `await` access to its
members.)

Even if you do not have the related record loaded, you can still retrieve the
record identifier:

``` swift
data.airports[0].tieInFSSID // returns a String identifier
```

## Topics

### Records

- ``Airport``
- ``ARTCC``
- ``FSS``
- ``Navaid``
- ``Record``
- ``State``

### Parsing

- ``NASR``
- ``NASRData``
- ``NASR/parse(_:withProgress:errorHandler:)``

### Associated Types

- ``Location``
- ``Offset``
- ``Remarks``
- ``Direction``
