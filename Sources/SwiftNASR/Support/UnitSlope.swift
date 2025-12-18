import Foundation

/// A unit of slope or gradient (rise over run).
///
/// ``UnitSlope`` provides units for measuring gradients, which describe the
/// steepness of inclines. In SwiftNASR, this is used for:
///
/// - Runway gradients (uphill/downhill slope)
/// - Climb gradients (feet per nautical mile)
/// - Clearance slopes (rise:run ratios)
///
/// ## Units
///
/// - ``gradient``: Decimal ratio (rise/run), base unit
/// - ``percentGrade``: Gradient × 100 (e.g., 2% grade)
/// - ``feetPerNauticalMile``: Aviation climb gradient standard
///
/// ## Usage
///
/// ```swift
/// // Runway gradient (1% uphill)
/// let runwayGradient = Measurement(value: 0.01, unit: UnitSlope.gradient)
///
/// // Climb gradient (318 ft/nm ≈ 3° flight path angle)
/// let climbGradient = Measurement(value: 318, unit: UnitSlope.feetPerNauticalMile)
/// ```
public final class UnitSlope: Dimension, @unchecked Sendable {
  /// Base unit: gradient = rise/run as decimal
  public static let gradient = UnitSlope(
    symbol: "m",
    converter: UnitConverterLinear(coefficient: 1.0)
  )

  /// Percent grade, or gradient × 100
  public static let percentGrade = UnitSlope(
    symbol: "%",
    converter: UnitConverterLinear(coefficient: 100.0)
  )

  /// Feet per nautical mile (ft/NM)
  public static let feetPerNauticalMile = UnitSlope(
    symbol: "ft/NM",
    converter: UnitConverterLinear(
      coefficient: Measurement(value: 1, unit: UnitLength.feet).converted(to: .nauticalMiles).value
    )
  )

  override public static func baseUnit() -> UnitSlope { .gradient }
}
