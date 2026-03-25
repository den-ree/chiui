# AGENTS.md (Chiui screen generation)

Chiui: context-based unidirectional state management for SwiftUI.

This file is intended for both AI agents and human maintainers generating new screens/features in apps that use Chiui. It encodes the architectural rules and the canonical API names so future automation does not drift.

## Architecture rules (non-negotiable)

1. Context owns the coordinator reference (to avoid coordinator/context cycles).
2. All store mutations go through `ContextViewModel.updateStore(_:)` (or directly through `context.store.update(state:)`).
3. `ContextViewModel.updateState(_:)` is the only place local view state is mutated; follow-up async work is chained with `then(_:)`.
4. Store -> view mapping happens in `ContextViewModel.didStoreUpdate(_:)`.
5. Views wire SwiftUI controls to view state and view model methods via `ContextualView.bindTo`.

## Canonical symbols to use

- Context: conform to `StoreContext`
- Store: `ContextualStore<StoreState>`
- View model: subclass `ContextViewModel<Context, ViewState>`
- Store->View mapping: `didStoreUpdate(_:)`
- Local state mutation: `updateState(_:) -> ContextualStateSideEffect`
- Async follow-ups: `then(_:)`
- Snapshotting local state for async work: `scopeState(_:_:)`
- SwiftUI wiring: `ContextualView` + `bindTo(_ : action:)`

## Step-by-step checklist

### 1. Define the Context

- Create a type that conforms to `StoreContext`.
- Add your coordinator reference as a stored property on the context.
- Provide the required `store: ContextualStore<StoreState>`.

```swift
final class FeatureContext: StoreContext {
  typealias StoreState = FeatureStoreState

  let store: ContextualStore<FeatureStoreState>
  let coordinator: AppCoordinator

  init(initialState: FeatureStoreState = .init(), coordinator: AppCoordinator) {
    self.store = ContextualStore(initialState)
    self.coordinator = coordinator
  }
}
```

### 2. Create the ViewModel

- Subclass `ContextViewModel<FeatureContext, FeatureViewModel.State>`.
- Override `didStoreUpdate(_:)` to map `StoreState` into `State` via `updateState`.

```swift
final class FeatureViewModel: ContextViewModel<FeatureContext, FeatureViewModel.State> {
  struct State: ContextualViewState {
    var value: String = ""
    init() {}
  }

  nonisolated override func didStoreUpdate(_ storeState: FeatureStoreState) async {
    await updateState { state in
      state.value = storeState.value
    }.then { _ in
      // Optional: run async follow-ups (analytics, navigation prep, etc.)
    }
  }

  @MainActor
  func onNextTapped() {
    context.coordinator.navigateToNextScreen()
  }
}
```

Notes:
- Use `guard change.hasChanged else { return }` inside `then(_:)` if you only want follow-ups when values changed.
- `then(_:)` runs on the main actor.

### 3. Build the View

- Conform to `ContextualView`.
- Declare `@StateObject var viewModel: YourViewModel`.
- Bind controls to view state properties using `bindTo` and forward writes to view model methods.

```swift
struct FeatureView: ContextualView {
  @StateObject var viewModel: FeatureViewModel

  init(_ context: FeatureContext) {
    _viewModel = .init(wrappedValue: .init(context))
  }

  var body: some View {
    VStack {
      TextField("Value", text: bindTo(\.value) { viewModel.updateValue($0) })
      Button("Next") { viewModel.onNextTapped() }
    }
  }
}
```

### 4. Integrate with the Coordinator

- The coordinator creates the next screen’s context.
- The view model reads the coordinator via `context.coordinator`.

```swift
final class AppCoordinator {
  func navigateToNextScreen() {
    // e.g., push FeatureView(FeatureContext(..., coordinator: self))
  }
}
```

## Patterns to avoid (stale names)

- `sideEffect` (use `updateState(_:)` + `.then(_:)` or `scopeState(_:_:)`)
- `then(wait:)` (not supported)
- `scopeStateOnStoreChange` (store->view mapping is `didStoreUpdate(_:)`)

## Optional: Where to look

- See the canonical shape in `Examples/DiaryApp`.

