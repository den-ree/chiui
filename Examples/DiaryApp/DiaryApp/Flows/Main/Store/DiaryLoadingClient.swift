import Foundation

/// Example client that is intentionally NOT `Sendable`.
///
/// In a real system, you would either:
/// - confine it to one actor/executor (like `@MainActor`), or
/// - wrap it behind an actor, or
/// - carefully use `@unchecked Sendable` at the boundary.
final class DiaryLoadingClient {
  private let formatter = DateFormatter()

  @MainActor
  func simulateLoadingWork() async {
    _ = formatter.string(from: Date())
    try? await Task.sleep(for: .seconds(2))
  }
}
