# SwiftNASR: FAA aeronautical data library for Swift

SwiftNASR is a Swift library that downloads and parses National Airspace System
Resource (NASR) distributions from the FAA's Facility Aerodrome Data Distribution System
(FADDS). These distributions contain comprehensive aeronautical data for the United
States, covering the airports, navaids, airspace, routes, ATC facilities, and more, that
make up the National Airspace System.

SwiftNASR can download NASR distributions directly from the FAA website, or load
prior-downloaded distributions from disk or memory. It parses this data into classes and
structs that are easy to use and take advantage of common Swift paradigms. These
classes are all `Codable` and can be exported to file, and imported using the `Coder` of
your choice.

The design goal of SwiftNASR is _domain-restricted data as much as possible_. Wherever
possible, SwiftNASR avoids representing data as open-ended types such as strings.
Instead, enums and other types with small domains are preferred. This obviously has
maintainability implications -- namely, as the upstream data changes, SwiftNASR is more
likely to generate parsing errors, and require more developer work to maintain future
compatibility -- but it also results in a library that's more in harmony with the design goals
of the Swift language itself (type safety, compile-time checks, etc.).

### What records can I parse with this?

SwiftNASR is a work in progress. Here's what's currently ready:

- [x] Airports
- [x] ARTCCs
- [x] FSSes
- [ ] ARTCC boundary segments
- [ ] Airways
- [ ] AWOSes
- [ ] Coded departure routes
- [ ] FSS comm facilities
  - The FSS data includes comm facilities, but there is also a separate file for FSS comm
    facilities; haven't checked yet if they contain the same data
- [ ] High altitude route fixes
- [ ] Published holds
- [ ] ILSes
- [ ] Location identifiers
- [ ] Miscellaneous activity areas
- [ ] Military training routes
- [ ] Enroute fixes
- [ ] Navaids
- [ ] Preferred routes
- [ ] Parachute jump activity areas
- [ ] DPs and STARs
- [ ] ATCTs and TRACONs
- [ ] Weather reporting locations

## Installation

SwiftNASR is a Swift Package Manager project. To use SwiftNASR, simply add this project
to your `Package.swift` file. Example:

```swift
// [...]
dependencies: [
    .package(url: "https://github.com/RISCfuture/SwiftNASR.git", .branch("master")),
]
// [...]
```

## Usage

The `NASR` class is used to load NASR distributions. If you have not already downloaded a
NASR distribution, you can do so using the `fromInternetToFile` method, which will
download the distribution to a file, so you can avoid having to re-download it later:

```swift
import SwiftNASR

let workingURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let distributionURL = workingURL.appendingPathComponent("distribution.zip")
let distribution = NASR.fromInternetToFile(distributionURL)!
```

If you have already downloaded the distribution, you can load it using
`fromLocalArchive`:

```swift
let distribution = NASR.fromLocalArchive(distributionURL)
```

Once you have your distribution, use the `NASR` class to asynchronously load the data and
parse it:

```swift
distribution.load { result in
    switch result {
        case .success:
            try! distribution.parse(.airports, errorHandler: { error in
                // [...]
            })

        case .failure(let error):
            // [...]
    }
}
```

Note that larger datasets, such as airports, can take several moments to parse. It's
recommended to serialize this data once parsed using an encoder (see below).

Once you've completed parsing the data you're interested in, you can access it from
`NASR.data`:

```swift
let sanCarlos = distribution.data.airports!.first { $0.LID == "SQL" }!
print(sanCarlos.runways[0].length)
```

`data` is an object of type `NASRData`. Its fields, such as `airports` will only not be nil
once `parse` has been called for that data type (as in the example above).

To avoid parsing a large dataset each time your application loads, I recommend encoding
the `NASRData` object. Choose the encoder you wish to use; for example, `JSONEncoder`
uses a straightforward and portable format. This class also provides `JSONZipEncoder` to
cut down on space when needed.

You can encode the whole object, containing all the data you've loaded:

```swift
let encoder = JSONZipEncoder()
let data = try encoder.encode(distribution.data)
try data.write(to: workingURL.appendingPathComponent("distribution.json.zip"))
```

or you can encode just the data you need; for example, filtering in only the airports that you
care about, to improve space and time efficiency when loading and working with the data:

```swift
let validAirports = distribution.data.airports!.filter { airport in
    return airport.publicUse &&
        airport.runways.filter { $0.isPaved && $0.length > 3000 }.count > 0
}
let data = try encoder.encode(validAirports)
```

For more information on the data you have available to work with, see the class
documentation for each of the record classes, such as `Airport`.

### Use as a Publisher

SwiftNASR can also be used as a `Publisher` for reactive apps written using Combine.
The `load` method has a variation that returns a publisher that emits when loading is
complete:

```swift
let distribution = NASR.fromLocalArchive(distributionURL)
let cancelable = distribution.loadPublisher().sink { distribution in
    // [...]
}
```

There are also variations of the `parse` method for each parseable type that return
Publishers that emit when parsing is complete:

``` swift
let distribution = NASR.fromLocalArchive(distributionURL)
let cancelable = distribution.loadPublisher().map { $0.parseAirports() }
    .switchToLatest().sink { event in _
        switch event {
            case let .error(error): // parse error for one row only
                // [...] (decide if you want to keep parsing or cancel)
            case let .complete(airports):
                // [...]
        }
    }
}

```

### Customizing loader behavior

If you need to customize loader behavior (e.g., using your own
`URLSessionConfiguration`), instantiate a loader yourself and pass it to the `NASR`
initializer. The different `NASR` class constructors are simply syntactic sugar for different
loader implementations. See the documentation for each `Loader` implementation for
more information.

## Documentation

Online API documentation and tutorials are available at
https://riscfuture.github.io/SwiftNASR/documentation/swiftnasr/

DocC documentation is available, including tutorials and API documentation. For
Xcode documentation, you can run

``` sh
swift package generate-documentation --target SwiftMETAR
```

to generate a docarchive at
`.build/plugins/Swift-DocC/outputs/SwiftMETAR.doccarchive`. You can open this
docarchive file in Xcode for browseable API documentation. Or, within Xcode,
open the SwiftNASR package in Xcode and choose **Build Documentation** from the
**Product** menu.

## Tests

Testing is done using Nimble and Quick. Simply run the `SwiftNASRTests` target to run
tests.

A `SwiftNASR_E2E` target is also available to do an end-to-end test. This will download a
distribution (or load one from file, if already downloaded) and load all data from the
distribution, then write it out to a `.json.zip` file. The whole process takes some time, but
if it completes successfully without error, that's a pretty good sign the code hasn't broken.
```
