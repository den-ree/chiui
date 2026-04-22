import Chiui

extension ContextViewModel {
  /// Runs ``send(_:)`` and awaits async effect handling when an effect was emitted (test sequencing).
  @MainActor
  func sendAwaitingEffects(_ action: Action) async {
    if let task = send(action) {
      await task.value
    }
  }
}
