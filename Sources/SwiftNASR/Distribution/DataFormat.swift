import Foundation

/**
 Represents the format of NASR data to parse.

 The FAA distributes NASR data in two formats:

 - **TXT (Fixed-Width)**: The traditional format where each field occupies a
   fixed number of characters. This format has been available for many years
   and is fully supported by SwiftNASR.

 - **CSV (Comma-Separated Values)**: A newer format where fields are separated
   by commas. This format is more compact and easier to parse, but may have
   slightly different field availability compared to TXT.

 When loading data from the FAA, you can specify which format to use via the
 `format` parameter on methods like ``NASR/fromInternetToFile(_:activeAt:format:)``
 or ``NASR/fromLocalDirectory(_:format:)``.

 ## Example

 ```swift
 // Load CSV format from the internet
 let nasr = NASR.fromInternetToMemory(format: .csv)

 // Load TXT format from a local directory
 let nasr = NASR.fromLocalDirectory(myURL, format: .txt)
 ```

 - Note: Not all record types are available in both formats. CSV format
   currently supports airports, ARTCCs, FSSs, and navaids.
 */
public enum DataFormat: String, Codable, Sendable {

  /// Traditional fixed-width text format.
  ///
  /// Each field occupies a fixed number of characters in the file. This is the
  /// original NASR distribution format and has the most complete field coverage.
  case txt = "TXT"

  /// Comma-separated values format.
  ///
  /// Fields are separated by commas. This format is more compact and includes
  /// header rows for field identification. Some fields available in TXT format
  /// may not be present in CSV format.
  case csv = "CSV"
}
