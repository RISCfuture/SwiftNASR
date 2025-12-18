import Foundation

public extension RunwayEnd {
  /// The date the threshold position was determined.
  var positionSourceDate: Date? {
    positionSourceDateComponents?.date
  }

  /// The date the threshold elevation was determined.
  var elevationSourceDate: Date? {
    elevationSourceDateComponents?.date
  }

  /// The date the displaced threshold position was determined.
  var displacedThresholdPositionSourceDate: Date? {
    displacedThresholdPositionSourceDateComponents?.date
  }

  /// The date the displaced threshold elevation was determined.
  var displacedThresholdElevationSourceDate: Date? {
    displacedThresholdElevationSourceDateComponents?.date
  }

  /// The date the TDZE was determined.
  var touchdownZoneElevationSourceDate: Date? {
    touchdownZoneElevationSourceDateComponents?.date
  }
}

// MARK: - RunwayEnd.LAHSOPoint

public extension RunwayEnd.LAHSOPoint {
  /// The date the position was determined.
  var positionSourceDate: Date? {
    positionSourceDateComponents?.date
  }
}
