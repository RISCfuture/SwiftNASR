import Foundation

public extension ILS {
  /// Information effective date.
  var effectiveDate: Date? {
    effectiveDateComponents?.date
  }
}

// MARK: - ILS.Localizer

public extension ILS.Localizer {
  /// Effective date of operational status.
  var statusDate: Date? {
    statusDateComponents?.date
  }
}

// MARK: - ILS.GlideSlope

public extension ILS.GlideSlope {
  /// Effective date of operational status.
  var statusDate: Date? {
    statusDateComponents?.date
  }
}

// MARK: - ILS.DME

public extension ILS.DME {
  /// Effective date of operational status.
  var statusDate: Date? {
    statusDateComponents?.date
  }
}

// MARK: - ILS.MarkerBeacon

public extension ILS.MarkerBeacon {
  /// Effective date of operational status.
  var statusDate: Date? {
    statusDateComponents?.date
  }
}
