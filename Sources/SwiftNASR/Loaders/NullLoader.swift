import Foundation

/**
 `NullLoader` is provided for API compatibility between loading data from a
 distribution and loading it directly from a serialized format. In both cases,
 you can access distribution data using the ``NASR/data`` method.
 
 The first time you want to access NASR data, you must load it from a
 distribution like so:
 
 
 ``` swift
 let distribution = NASR.fromInternetToFile(distributionURL)!
 try distribution.parse(.airports, errorHandler: { error in
     // [...]
 })
 ```
 
 You then access data using the ``NASR/data`` method:
 
 ``` swift
 let airports = distribution.data.airports
 ```
 
 You can serialize this data to avoid having to parse it from the distribution
 each time:
 
 ``` swift
 let encoder = JSONZipEncoder()
 let data = try encoder.encode(distribution.data)
 try data.write(to: serializedDataURL)
 ```
 
 But when deserializing it, you no longer have access to the original
 ``NASR`` instance. A `NullLoader` allows you to attach a ``NASR`` instance to
 your deserialized data, so that you can access it in the same manner as if it
 were just loaded from a distribution:
 
 ``` swift
 let decoder = JSONZipDecoder()
 let data = try decoder.decode(NASRData.Type, from: serializedDataURL)
 let distribution = NASR.fromData(data)
 ```
 
 ``NASR/fromData(_:)`` uses `NullLoader` to accomplish this.
 */

public final class NullLoader: Loader {

    /**
     Yields a ``NullDistribution`` that cannot be used to parse NASR data.
     */

    public func load(withProgress progressHandler: @Sendable (Progress) -> Void = { _ in }) throws -> Distribution {
        progressHandler(completedProgress())
        return NullDistribution()
    }
}
