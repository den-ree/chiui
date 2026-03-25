import Foundation

enum TestUtils {
  /// Polls `predicate` until it returns `true` or the timeout elapses.
  static func waitUntil(
    timeout: Duration,
    pollInterval: Duration = .milliseconds(5),
    _ predicate: @escaping @Sendable () async -> Bool
  ) async -> Bool {
    let start = ContinuousClock().now
    while ContinuousClock().now - start < timeout {
      if await predicate() { return true }
      try? await Task.sleep(for: pollInterval)
    }
    return await predicate()
  }
}

