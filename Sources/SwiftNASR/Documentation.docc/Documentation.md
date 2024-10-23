# ``SwiftNASR``

A library for downloading and working with aeronautical data from the FAA's
Facility Aeronautical Data Distribution System (FADDS).

## Overview

SwiftNASR is a Swift library that downloads and parses National Airspace System
Resource (NASR) distributions from the FAA's Facility Aerodrome Data Distribution
System (FADDS). These distributions contain comprehensive aeronautical data for
the United States, covering the airports, navaids, airspace, routes, ATC
facilities, and more, that make up the National Airspace System.

SwiftNASR can download NASR distributions directly from the FAA website, or load
prior-downloaded distributions from disk or memory. It parses this data into
classes and structs that are easy to use and take advantage of common Swift
paradigms. These classes are all `Codable` and can be exported to file, and
imported using the `Coder` of your choice.

The design goal of SwiftNASR is _domain-restricted data as much as possible_.
Wherever possible, SwiftNASR avoids representing data as open-ended types such
as strings. Instead, enums and other types with small domains are preferred.
This obviously has maintainability implications -- namely, as the upstream data
changes, SwiftNASR is more likely to generate parsing errors, and require more
developer work to maintain future compatibility -- but it also results in a
library that's more in harmony with the design goals of the Swift language
itself (type safety, compile-time checks, etc.).

## Topics

### Basics

- <doc:Getting-Started>
- ``NASR``
- ``NASRData``

### NASR Records

- <doc:Records>
- ``Airport``
- ``ARTCC``
- ``FSS``
- ``Navaid``

### Distributions

- <doc:Working-with-Distributions>
- ``Distribution``

### Loaders

- <doc:Working-with-Loaders>
- ``Loader``
- ``Downloader``

### ZIP Coders

- ``JSONZipEncoder``
- ``JSONZipDecoder``

### Errors

- ``Cycle``
- ``Error``
