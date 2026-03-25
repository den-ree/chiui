import Foundation
import CIUA

/// Context for managing diary state and actions
final class DiaryContext: StoreContext {
  /// The store managing the diary state
  let store: ContextualStore<DiaryStoreState>

  /// Example of a non-Sendable dependency.
  /// We keep access confined to `@MainActor` via the view model's `then { @MainActor ... }` chain.
  let loadingClient: DiaryLoadingClient

  /// Creates a new diary context
  /// - Parameter initialState: Initial state for the store
  init(initialState: DiaryStoreState = .init()) {
    self.store = ContextualStore(initialState)
    self.loadingClient = DiaryLoadingClient()
  }
}

// The context is allowed to be `Sendable` even if it contains non-Sendable dependencies.
// The contract is that we only touch `loadingClient` from `@MainActor`.
extension DiaryContext: @unchecked Sendable {}
