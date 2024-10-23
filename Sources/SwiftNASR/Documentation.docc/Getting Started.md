# Getting Started

A basic overview of how to use SwiftNASR to load and parse FAA aeronautical
data.

## Overview

The ``NASR`` class is used to load NASR distributions. If you have not already
downloaded a NASR distribution, you can do so using the
``NASR/fromInternetToFile(_:activeAt:)`` method, which will download the
distribution to a file, so you can avoid having to re-download it later:

```swift
import SwiftNASR

let workingURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let distributionURL = workingURL.appendingPathComponent("distribution.zip")
let distribution = NASR.fromInternetToFile(distributionURL)!
```

If you have already downloaded the distribution, you can load it using
``NASR/fromLocalArchive(_:)``:

```swift
let distribution = NASR.fromLocalArchive(distributionURL)
```

Once you have your distribution, use the ``NASR`` class to asynchronously load
the data and parse it:

```swift
try await distribution.load()
try await distribution.parse(.airports, errorHandler: { error in
    // [...]
})
```

Note that larger datasets, such as airports, can take several moments to parse.
It's recommended to serialize this data once parsed using an encoder (see
below).

Once you've completed parsing the data you're interested in, you can access it
from ``NASR/data``:

```swift
let sanCarlos = distribution.data.airports!.first { $0.LID == "SQL" }!
print(sanCarlos.runways[0].length)
```

`data` is an object of type ``NASRData``. Its fields, such as
``NASRData/airports`` will only not be `nil` once
``NASR/parse(_:withProgress:errorHandler:)`` has been called for that data type
(as in the example above).

To avoid parsing a large dataset each time your application loads, I recommend
encoding the ``NASRData`` object. Choose the encoder you wish to use; for
example, `JSONEncoder` uses a straightforward and portable format. This class
also provides ``JSONZipEncoder`` to cut down on space when needed.

You can encode the whole object, containing all the data you've loaded:

```swift
let encoder = JSONZipEncoder()
let data = try encoder.encode(NASRDataCodable(data: distribution.data))
try data.write(to: workingURL.appendingPathComponent("distribution.json.zip"))
```

or you can encode just the data you need; for example, filtering in only the
airports that you care about, to improve space and time efficiency when loading
and working with the data:

```swift
let validAirports = distribution.data.airports!.filter { airport in
    return airport.publicUse &&
        airport.runways.filter { $0.isPaved && $0.length > 3000 }.count > 0
}
let data = try encoder.encode(validAirports)
```

For more information on the data you have available to work with, see the class
documentation for each of the record classes, such as ``Airport``.

### Customizing loader behavior

If you need to customize loader behavior (e.g., using your own
`URLSessionConfiguration`), instantiate a loader yourself and pass it to the
``NASR/init(loader:)`` initializer. The different ``NASR`` class constructors
are simply syntactic sugar for different loader implementations. See the
documentation for each ``Loader`` implementation for more information.
