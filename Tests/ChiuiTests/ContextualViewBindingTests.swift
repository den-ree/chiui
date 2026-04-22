import Foundation
import SwiftUI
import Testing
@testable import Chiui

private struct BindingTestStoreState: ContextualStoreState {
  var value: Int = 0
}

private struct BindingTestViewState: ContextualViewState {
  var title: String = ""
}

private struct BindingTestContext: StoreContext {
  typealias StoreState = BindingTestStoreState
  let store: ContextualStore<BindingTestStoreState>

  init() { self.store = ContextualStore(.init()) }
}

private enum BindingTestAction: Equatable, ContextualAction {
  case storeChanged(BindingTestStoreState)
  case titleChanged(String)
}

@MainActor
private final class BindingTestViewModel: ContextViewModel<
  BindingTestContext,
  BindingTestViewState,
  BindingTestAction,
  Never
> {
  override class func respond(to action: BindingTestAction, state: inout BindingTestViewState) -> Never? {
    switch action {
    case .storeChanged:
      return nil
    case .titleChanged(let newTitle):
      state.title = newTitle
      return nil
    }
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
  @Test("bindTo reads from ViewState and dispatches the mapped action on writes")
  func testBindToGetSetForwarding() async throws {
    let context = BindingTestContext()
    let viewModel = BindingTestViewModel(context)
    let view = BindingTestView(viewModel: viewModel)

    #expect(view.state.title == "")

    let binding = view.bindTo(\.title) { .titleChanged($0) }

    binding.wrappedValue = "Hello"
    #expect(viewModel.state.title == "Hello")
    #expect(binding.wrappedValue == "Hello")
  }
}
