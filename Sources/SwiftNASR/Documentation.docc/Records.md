# Records

SwiftNASR records represent the data types present in a NASR distribution.
After one of the `load` methods is called (see _Loaders_), records can be
parsed.

Records are stored in a ``NASRData`` instance after being loaded by one of the
`parse` methods:

* ``NASR/parse(_:withProgress:errorHandler:completionHandler:)``
* The publisher methods:
  ``NASR/parseAirportsPublisher(errorHandler:withProgress:)`` etc.
* The async methods: ``NASR/parseAirports(withProgress:errorHandler:)``, etc.

Each record maintains an internal link back to its parent ``NASRData`` object.
This is used to allow records to cross-reference each other; e.g., the
``Airport/tieInFSS`` method links to an ``FSS`` object, but only if the FSS
records have been loaded with a prior `load` call:

``` swift
let data: NASRData // previously initialized
await data.parseAirports()
data.airports[0].tieInFSS // will always be nil since FSSes have not been loaded
await data.parseFSSes()
data.airports[0].tieInFSS // will not be nil if present in the distribution data
```

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
- ``NASR/parse(_:withProgress:errorHandler:completionHandler:)``

### Parsing with Combine

- ``NASR/parseAirportsPublisher(errorHandler:withProgress:)``
- ``NASR/parseARTCCsPublisher(errorHandler:withProgress:)``
- ``NASR/parseFSSesPublisher(errorHandler:withProgress:)``
- ``NASR/parseNavaidsPublisher(errorHandler:withProgress:)``

### Parsing Async

- ``NASR/parseAirports(withProgress:errorHandler:)``
- ``NASR/parseARTCCs(withProgress:errorHandler:)``
- ``NASR/parseFSSes(withProgress:errorHandler:)``
- ``NASR/parseNavaids(withProgress:errorHandler:)``

### Associated Types

- ``Location``
- ``Offset``
- ``Remarks``
- ``Direction``
