import Foundation
import Combine

/**
 `NullLoader` is provided for API compatibility between loading data from a
 distribution and loading it directly from a serialized format. In both cases,
 you can access distribution data using the `SwiftNASR.data` method.
 
 The first time you want to access NASR data, you must load it from a
 distribution like so:
 
 
 ``` swift
 let distribution = SwiftNASR.fromInternetToFile(distributionURL)!
 try! distribution.parse(.airports, errorHandler: { error in
     // [...]
 })
 ```
 
 You then access data using the `SwiftNASR.data` method:
 
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
 `SwiftNASR` instance. A `NullLoader` allows you to attach a `SwiftNASR`
 instance to your deserialized data, so that you can access it in the same
 manner as if it were just loaded from a distribution:
 
 ``` swift
 let decoder = JSONZipDecoder()
 let data = try! decoder.decode(NASRData.Type, from: serializedDataURL)
 let distribution = SwiftNASR.fromData(data)
 ```
 
 `SwiftNASR.fromData` uses `NullLoader` to accomplish this.
 */

public class NullLoader: Loader {
    
    /**
     Yields a `NullDistribution` that cannot be used to parse NASR data.
     */
    
    public func load(callback: @escaping (_ result: Result<Distribution, Swift.Error>) -> Void) {
        callback(.success(NullDistribution()))
    }
    
    @available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func load() -> AnyPublisher<Distribution, Swift.Error> {
        return Result.Publisher(NullDistribution()).eraseToAnyPublisher()
    }
}
