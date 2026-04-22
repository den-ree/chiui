# AGENTS.md (Chiui screen generation)

Chiui: context-based unidirectional state management for SwiftUI.

This file is intended for both AI agents and human maintainers generating new screens/features in apps that use Chiui. It encodes the architectural rules and the canonical API names so future automation does not drift.

## Architecture rules (non-negotiable)

1. Context owns the coordinator reference (to avoid coordinator/context cycles).
2. All store mutations go through `ContextViewModel.updateStore(_:)` (or directly through `context.store.update(state:)`).
3. `ContextViewModel.send(_:)` is the canonical entry point for user/store actions.
4. `ContextViewModel.respond(to:state:)` is the only place local view state is mutated.
5. Async follow-up work runs in `ContextViewModel.handle(_:)`.
6. Store -> view mapping happens in `ContextViewModel.respond(to:state:)` via `.storeChanged` actions.
7. Views wire SwiftUI controls to view state and view model actions via `ContextualView.bindTo`.

## Canonical symbols to use

- Context: conform to `StoreContext`
- Store: `ContextualStore<StoreState>`
- View model: subclass `ContextViewModel<Context, ViewState, Action, Effect>`
- Action contract: `ContextualAction` (`Equatable`, `Sendable`, includes `.storeChanged(StoreState)`)
- Store->View mapping: `respond(to:state:)` handling `.storeChanged`
- Action entry point: `send(_:)` (sync; returns `Task<Void, Never>?` when an effect runs — await only when needed)
- State reducer: `respond(to:state:) -> Effect?`
- Effect runner: `handle(_:)`
- Local state primitive: `updateState(_:) -> ContextualStateChange`
- Snapshotting local state for async work: `scopeState(_:_:)`
- SwiftUI wiring: `ContextualView` + `bindTo(_ : action:)` + optional `send(_:)` shorthand on `ContextualView`

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

- Subclass `ContextViewModel<FeatureContext, FeatureViewModel.State, FeatureViewModel.Action, FeatureViewModel.Effect>`.
- Define `Action` and `Effect`.
- Implement `respond(to:state:)` for pure state transitions.
- Implement `handle(_:)` for async side effects.
- Make `Action` conform to `ContextualAction` with a `.storeChanged(StoreState)` case.

```swift
final class FeatureViewModel: ContextViewModel<
  FeatureContext,
  FeatureViewModel.State,
  FeatureViewModel.Action,
  FeatureViewModel.Effect
> {
  struct State: ContextualViewState {
    var value: String = ""
    init() {}
  }

  enum Action: ContextualAction {
    case storeChanged(FeatureStoreState)
    case valueChanged(String)
    case nextTapped
  }

  enum Effect {
    case persistValue(String)
    case navigateToNext
  }

  override class func respond(to action: Action, state: inout State) -> Effect? {
    switch action {
    case .storeChanged(let storeState):
      state.value = storeState.value
      return nil
    case .valueChanged(let value):
      state.value = value
      return .persistValue(value)
    case .nextTapped:
      return .navigateToNext
    }
  }

  override func handle(_ effect: Effect) async {
    switch effect {
    case .persistValue(let value):
      await updateStore { $0.value = value }
    case .navigateToNext:
      context.coordinator.navigateToNextScreen()
    }
  }
}
```

Notes:
- Keep `respond(to:state:)` pure (state in, effect out).
- Use `send(_:)` from views; store updates are delivered as `.storeChanged` actions automatically.

### 3. Build the View

- Conform to `ContextualView`.
- Declare `@State var viewModel: YourViewModel`.
- Bind controls to view state properties using `bindTo`. The trailing closure returns the `Action` to dispatch for the new bound value — Chiui calls `send(_:)` internally.

```swift
struct FeatureView: ContextualView {
  @State var viewModel: FeatureViewModel

  init(_ context: FeatureContext) {
    _viewModel = .init(initialValue: .init(context))
  }

  var body: some View {
    VStack {
      TextField("Value", text: bindTo(\.value) { .valueChanged($0) })
      Button("Next") {
        send(.nextTapped)
      }
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

- `sideEffect`
- `.then(_:)`
- `then(wait:)` (not supported)
- `scopeStateOnStoreChange` (store->view mapping happens in `respond(.storeChanged(...))`)

## Optional: Where to look

- See the canonical shape in `Examples/DiaryApp`.

