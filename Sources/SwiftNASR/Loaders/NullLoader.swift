import Foundation
import Combine

/**
 `NullLoader` is provided for API compatibility between loading data from a
 distribution and loading it directly from a serialized format. In both cases,
 you can access distribution data using the ``NASR/data`` method.
 
 The first time you want to access NASR data, you must load it from a
 distribution like so:
 
 
 ``` swift
 let distribution = NASR.fromInternetToFile(distributionURL)!
 try! distribution.parse(.airports, errorHandler: { error in
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
 let data = try! decoder.decode(NASRData.Type, from: serializedDataURL)
 let distribution = NASR.fromData(data)
 ```
 
 ``NASR/fromData(_:)`` uses `NullLoader` to accomplish this.
 */

public class NullLoader: Loader {
    
    /**
     Yields a ``NullDistribution`` that cannot be used to parse NASR data.
     */
    
    public func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }, callback: @escaping (_ result: Result<Distribution, Swift.Error>) -> Void) {
        progressHandler(completedProgress())
        callback(.success(NullDistribution()))
    }
    
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func loadPublisher(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) -> AnyPublisher<Distribution, Swift.Error> {
        progressHandler(completedProgress())
        return Result.Publisher(NullDistribution()).eraseToAnyPublisher()
    }
    
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public func load(withProgress progressHandler: @escaping (Progress) -> Void = { _ in }) async throws -> Distribution {
        progressHandler(completedProgress())
        return NullDistribution()
    }
}
