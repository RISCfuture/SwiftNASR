import Foundation

public extension Airport {
  /// The epoch date of the World Magnetic Model that was used to determine
  /// the magnetic variation.
  var magneticVariationEpoch: Date? {
    magneticVariationEpochComponents?.date
  }

  /// The date at which the ARP was determined.
  var positionSourceDate: Date? {
    positionSourceDateComponents?.date
  }

  /// The date at which the airport elevation was determined.
  var elevationSourceDate: Date? {
    elevationSourceDateComponents?.date
  }

  /// The date that the airport was first activated.
  var activationDate: Date? {
    activationDateComponents?.date
  }

  /// The date the last physical inspection was made.
  var lastPhysicalInspectionDate: Date? {
    lastPhysicalInspectionDateComponents?.date
  }

  /// The date the last request for information for this airport was completed.
  var lastInformationRequestCompletedDate: Date? {
    lastInformationRequestCompletedDateComponents?.date
  }

  /// The ending date of the one-year period that the operation statistics
  /// are counted from.
  var annualPeriodEndDate: Date? {
    annualPeriodEndDateComponents?.date
  }
}

// MARK: - Airport.ARFFCapability

public extension Airport.ARFFCapability {
  /// ARFF certification date.
  var certificationDate: Date? {
    certificationDateComponents.date
  }
}
