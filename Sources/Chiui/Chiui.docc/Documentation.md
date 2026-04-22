# ``Chiui``

Context-based unidirectional state management for SwiftUI.

## Overview

Chiui is an MVI-style architecture for SwiftUI built on Swift Concurrency and the `@Observable` macro.

Data flow:

```
Store (actor) ─ subscribe ─▶ send(.storeChanged) ─▶ respond ─▶ state
                                                                      │
                                                                      └─▶ Effect? ─▶ handle ─▶ updateStore / network / navigation
```

Four primitives:

- ``ContextViewModel/send(_:)`` — synchronous entry for actions; returns a task only when the reducer emitted an effect (so you can await effect completion when tests or sequencing require it).
- ``ContextViewModel/respond(to:state:)`` — pure sync reducer that mutates view state and emits an optional `Effect`.
- ``ContextViewModel/handle(_:)`` — runs async side effects.
- ``ContextViewModel/updateStore(_:)`` — atomic mutation of source-of-truth store state.

The architecture enforces two separations:

1. **Decision vs. execution.** `respond` decides *what* should happen; `handle` does it.
2. **Local vs. global.** `state` is per-view; the store is shared.

## Getting Started

### 1. Define States and Context

```swift
struct AppStoreState: ContextualStoreState {
    var user: User?
    var isAuthenticated: Bool = false
}

struct ProfileState: ContextualViewState {
    var displayName: String = ""
    var isEditing: Bool = false
    var isSaving: Bool = false
    var validationError: String?
    init() {}
}

final class AppContext: StoreContext {
    typealias StoreState = AppStoreState
    let store: ContextualStore<AppStoreState>
    let coordinator: AppCoordinator
    let api: ProfileAPI

    init(store: ContextualStore<AppStoreState>, coordinator: AppCoordinator, api: ProfileAPI) {
        self.store = store
        self.coordinator = coordinator
        self.api = api
    }
}
```

### 2. Implement View Model

```swift
final class ProfileViewModel: ContextViewModel<AppContext, ProfileState, ProfileViewModel.Action, ProfileViewModel.Effect> {
    enum Action: ContextualAction {
        case storeChanged(AppStoreState)
        case nameChanged(String)
        case startEditing
        case saveTapped
        case saved
    }

    enum Effect {
        case persistName(String)
        case save(name: String)
    }

    override class func respond(to action: Action, state: inout ProfileState) -> Effect? {
        switch action {
        case .storeChanged(let storeState):
            state.displayName = storeState.user?.name ?? ""
            state.isSaving = false
            return nil
        case .nameChanged(let name):
            state.displayName = name
            state.validationError = validate(name)
            return state.validationError == nil ? .persistName(name) : nil
        case .startEditing:
            state.isEditing = true
            return nil
        case .saveTapped:
            state.isSaving = true
            return .save(name: state.displayName)
        case .saved:
            state.isSaving = false
            state.isEditing = false
            return nil
        }
    }

    override func handle(_ effect: Effect) async {
        switch effect {
        case .persistName(let name):
            await updateStore { $0.user?.name = name }
        case .save(let name):
            try? await context.api.save(name: name)
            send(.saved)
        }
    }

    private static func validate(_ name: String) -> String? {
        name.isEmpty ? "Name cannot be empty" : nil
    }
}
```

### 3. Use in SwiftUI

```swift
struct ProfileView: ContextualView {
    @State var viewModel: ProfileViewModel

    init(_ context: AppContext) {
        _viewModel = .init(initialValue: .init(context))
    }

    var body: some View {
        Form {
            TextField("Name", text: bindTo(\.displayName) { .nameChanged($0) })

            Button("Save") {
                send(.saveTapped)
            }
            .disabled(state.isSaving || state.validationError != nil)
        }
    }
}
```

## Architectural Rules

1. **`respond(to:state:)` is a `class func` and must stay pure.** It has no `self` — it cannot call `updateStore`, read the store, or touch the coordinator. Same `(Action, State)` in → same `(State, Effect?)` out.
2. **All side effects live in `handle(_:)`.** Network, disk, store writes, navigation — everything async goes here.
3. **Store writes only through `updateStore(_:)`.** This closure runs *inside* the store actor, making the mutation atomic and race-free.
4. **Only `state` is observable.** `ContextViewModel` marks every internal property with `@ObservationIgnored`. Subclasses should do the same for any stored property that isn't part of the view contract.
5. **Store snapshots flow through `.storeChanged`.** Reducers map store state in `respond` so mapping logic stays testable.
6. **Context owns dependencies.** Coordinator, API clients, services. View models read them via `context.…`.
7. **Views only dispatch.** Call `send(...)` from actions and bindings. Only `await` the returned task when you must wait for async effect completion. Views never mutate state or write to the store directly.

## Testing

The reducer is a pure `class func`, so you can test it without a store, network, or actor:

```swift
func testNameChangedValidates() {
    var state = ProfileState()
    let effect = ProfileViewModel.respond(to: .nameChanged(""), state: &state)

    XCTAssertEqual(state.displayName, "")
    XCTAssertEqual(state.validationError, "Name cannot be empty")
    XCTAssertNil(effect)
}
```

For integration tests, drive via `send(_:)` and observe `viewModel.state` or the store:

```swift
func testSaveCompletesFlow() async {
    let sut = ProfileViewModel(context)
    if let task = sut.send(.nameChanged("Ada")) { await task.value }
    if let task = sut.send(.saveTapped) { await task.value }
    // handle(.save) runs and `.saved` is processed
    XCTAssertFalse(sut.state.isSaving)
    XCTAssertFalse(sut.state.isEditing)
}
```

## Requirements

- iOS 17.0+
- macOS 14.0+
- Swift 5.9+
- Xcode 15.0+

## Topics

### Essentials

- ``StoreContext``
- ``ContextualStore``
- ``ContextViewModel``
- ``ContextualView``

### State

- ``ContextualStoreState``
- ``ContextualViewState``
- ``ContextualStateChange``
