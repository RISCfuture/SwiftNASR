import Foundation

/// String extension for safe substring operations used by fixed-width parsers.
extension String {
  /// Extract a substring starting at `start` position with given `length`.
  /// Returns empty string if start is out of bounds.
  /// - Parameters:
  ///   - start: Zero-based start position
  ///   - length: Number of characters to extract
  /// - Returns: The extracted substring, or empty string if out of bounds
  func substring(_ start: Int, _ length: Int) -> String {
    guard start >= 0, start < count else { return "" }
    let startIndex = index(self.startIndex, offsetBy: start)
    let endOffset = min(start + length, count)
    let endIndex = index(self.startIndex, offsetBy: endOffset)
    return String(self[startIndex..<endIndex])
  }
}
