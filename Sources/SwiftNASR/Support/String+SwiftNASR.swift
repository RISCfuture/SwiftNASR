import Foundation

extension String {
  func partitionSlices(by length: Int) -> [Substring] {
    var startIndex = self.startIndex
    var results = [Substring]()

    while startIndex < self.endIndex {
      let endIndex =
        self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
      results.append(self[startIndex..<endIndex])
      startIndex = endIndex
    }

    return results
  }

  func partition(by length: Int) -> [String] {
    return partitionSlices(by: length).map { String($0) }
  }

  /// Splits on any character in `separator`, like the standard-library
  /// `split(whereSeparator:)`: separator characters are dropped and empty
  /// subsequences (from leading, trailing, or consecutive separators) are
  /// omitted.
  func split(separator: CharacterSet) -> [Substring] {
    split(whereSeparator: { separator.contains($0.unicodeScalars.first!) })
  }
}
