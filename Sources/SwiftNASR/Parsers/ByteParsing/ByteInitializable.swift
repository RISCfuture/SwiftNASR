/// Protocol for types that can be initialized from a single ASCII byte.
///
/// Use this for enums where each case is represented by a single character,
/// such as direction indicators (N/S/E/W) or single-letter codes.
public protocol ByteInitializable {
  /// Creates an instance from a single ASCII byte, or nil if the byte is invalid.
  init?(byte: UInt8)
}

/// Protocol for types that can be initialized from a byte slice.
///
/// Use this for enums or types that require multiple bytes, such as
/// record type identifiers or multi-character codes.
public protocol ByteSliceInitializable {
  /// Creates an instance from a byte slice, or nil if the bytes are invalid.
  init?<Bytes: RandomAccessCollection>(bytes: Bytes) where Bytes.Element == UInt8
}
