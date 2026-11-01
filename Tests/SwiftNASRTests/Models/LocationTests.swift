import Foundation
import Testing

@testable import SwiftNASR

#if canImport(CoreLocation)
  import CoreLocation
#endif

@Suite
struct LocationTests {
  /// Oakland International's reference point, 37-43-16.5410N 122-13-16.1420W.
  private let location = Location(latitudeArcsec: 135_796.541, longitudeArcsec: -439_996.142)

  @Test
  func `converts the reference point to exact degrees`() {
    #expect(abs(location.latitude.converted(to: .degrees).value - 37.721261) < 1e-5)
    #expect(abs(location.longitude.converted(to: .degrees).value - -122.221151) < 1e-5)

    #if canImport(CoreLocation)
      #expect(abs(location.coordinate.latitude - 37.721261) < 1e-5)
      #expect(abs(location.coordinate.longitude - -122.221151) < 1e-5)
    #endif
  }
}
