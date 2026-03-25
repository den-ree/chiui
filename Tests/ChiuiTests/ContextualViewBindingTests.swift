import Foundation
import SwiftUI
import Testing
@testable import Chiui

private struct BindingTestStoreState: ContextualStoreState {
  var value: Int = 0
}

private struct BindingTestViewState: ContextualViewState {
  var title: String = ""
  init() {}
}

private struct BindingTestContext: StoreContext {
  typealias StoreState = BindingTestStoreState
  let store: ContextualStore<BindingTestStoreState>

  init() { self.store = ContextualStore(.init()) }
}

@MainActor
private final class BindingTestViewModel: ContextViewModel<BindingTestContext, BindingTestViewState> {
  nonisolated override func didStoreUpdate(_ storeState: BindingTestStoreState) async {
    // Intentionally no-op for this binding test.
    _ = storeState
  }
}

private struct BindingTestView: ContextualView {
  typealias InjectedStoreContext = BindingTestContext
  typealias ViewState = BindingTestViewState
  typealias ViewModel = BindingTestViewModel

  let viewModel: ViewModel

  var body: some View {
    EmptyView()
  }
}

@MainActor
@Suite("Chiui ContextualView Binding Tests")
struct ContextualViewBindingTests {
  @Test("bindTo reads from ViewState and forwards writes to onSet")
  func testBindToGetSetForwarding() async throws {
    let context = BindingTestContext()
    let viewModel = BindingTestViewModel(context)
    let view = BindingTestView(viewModel: viewModel)

    // Initial getter.
    #expect(view.state.title == "")

    let binding = view.bindTo(\.title) { newTitle in
      _ = viewModel.updateState { $0.title = newTitle }
    }

    // Setter should forward into the provided closure.
    binding.wrappedValue = "Hello"
    #expect(viewModel.viewState.title == "Hello")
    #expect(binding.wrappedValue == "Hello")
  }
}

