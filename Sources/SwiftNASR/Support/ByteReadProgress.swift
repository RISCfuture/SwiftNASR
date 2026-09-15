internal import Foundation

/**
 Reports a byte-oriented read to a `ProgressManager`, keeping the manager's unit counts and its
 `totalByteCount`/`completedByteCount` properties in step.

 A read starts out indeterminate. Every reader in this package hands its caller a stream before it
 knows how large the read will be — a file's size, an archive entry's uncompressed size, or a
 response's `Content-Length` — so the total arrives through ``setTotal(_:)`` once it is known.

 A `nil` subprogress means the caller asked for no progress reporting, in which case every method
 here does nothing.
 */
struct ByteReadProgress: Sendable {
  private let manager: ProgressManager?

  /// Begins reporting into `subprogress`, or reports nothing if it is `nil`.
  init(_ subprogress: consuming Subprogress?) {
    manager = subprogress?.start(totalCount: nil)
  }

  /// Declares how many bytes the read covers in total.
  func setTotal(_ bytes: Int) {
    manager?.setCounts { _, total in total = bytes }
    manager?.totalByteCount = UInt64(clamping: bytes)
  }

  /// Records that `bytes` further bytes have been read.
  func advance(by bytes: Int) {
    manager?.complete(count: bytes)
    manager?.completedByteCount += UInt64(clamping: bytes)
  }

  /// Records an absolute position in a read whose total the reader learns as it goes, such as a
  /// download reporting against a `Content-Length` that only arrives with the first response.
  func update(completed: Int, total: Int) {
    manager?.setCounts { completedCount, totalCount in
      completedCount = completed
      totalCount = total
    }
    manager?.totalByteCount = UInt64(clamping: total)
    manager?.completedByteCount = UInt64(clamping: completed)
  }
}

/// Marks a subprogress finished without tracking any work, for the loaders and readers that have
/// nothing to report because their work is already done by the time they are called.
func completeImmediately(_ subprogress: consuming Subprogress?) {
  subprogress?.start(totalCount: 1).complete(count: 1)
}
