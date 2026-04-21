import Foundation
import Chiui

final class DiaryContext: StoreContext {
  let store: ContextualStore<DiaryStoreState>
  let loadingClient: DiaryLoadingClient

  init(initialState: DiaryStoreState = .init()) {
    self.store = ContextualStore(initialState)
    self.loadingClient = DiaryLoadingClient()
  }
}

// The context is allowed to be `Sendable` even if it contains non-Sendable dependencies.
// The contract is that we only touch `loadingClient` from `@MainActor`.
extension DiaryContext: @unchecked Sendable {}
