<h1><img src="assets/icon.png" alt="Chiui logo" width="28" /> Chiui</h1>

Context-based unidirectional state management for SwiftUI, built on Swift Concurrency.

![CI](https://github.com/den-ree/chiui/actions/workflows/ci.yml/badge.svg)
![Release](https://github.com/den-ree/chiui/actions/workflows/release.yml/badge.svg)

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/den-ree/chiui", from: "1.1.0")
]
```

## Why Chiui

- **Unidirectional flow.** `Store -> ViewModel -> State -> View -> Action -> ViewModel -> Store`.
- **Pure reducer.** `respond(to:state:)` is a `class func` — deterministic, testable without mocks.
- **Explicit effects.** All async work (store writes, network, navigation) lives in `handle(_:)`.
- **One observable surface.** The view model exposes a single `state` property; everything else is `@ObservationIgnored`.
- **No implicit chaining.** Async flow is expressed with ordinary `await`, not closures or `.then`.

## Concepts

| Symbol | Role |
|---|---|
| `ContextualStore<State>` | Actor-isolated source of truth. |
| `StoreContext` | DI container owning the store + coordinator + services. |
| `ContextViewModel<Context, State, Action, Effect>` | `@Observable` view model. |
| `ContextualAction` | `Action` contract (`Equatable`, `Sendable`) that includes `.storeChanged(StoreState)`. |
| `send(_:) -> Task<Void, Never>?` | Sync entry for actions; returns a task only when `handle` runs. |
| `respond(to:state:) -> Effect?` | Pure sync reducer. Mutates `inout State`, returns optional `Effect`. |
| `handle(_:) async` | Executes async side effects emitted by the reducer. |
| `updateStore(_:) async` | Atomic mutation of store state (runs inside the store actor). |
| `ContextualView` | SwiftUI view with `state` + `bindTo(_:action:)` helpers. |

## Usage

### 1. Store and action types

```swift
struct EntryStoreState: ContextualStoreState {
    var entries: [Entry] = []
    var selectedId: Entry.ID?
}

struct EntryState: ContextualViewState {
    var title: String = ""
    var isSaving: Bool = false
    init() {}
}
```

### 2. View model

```swift
final class EntryViewModel: ContextViewModel<EntryContext, EntryState, EntryViewModel.Action, EntryViewModel.Effect> {
    enum Action: ContextualAction {
        case storeChanged(EntryStoreState)
        case titleChanged(String)
        case saveTapped
        case saved
    }

    enum Effect {
        case persistTitle(String)
        case save(title: String)
    }

    override class func respond(to action: Action, state: inout EntryState) -> Effect? {
        switch action {
        case .storeChanged(let store):
            state.title = store.entries.first { $0.id == store.selectedId }?.title ?? ""
            state.isSaving = false
            return nil
        case .titleChanged(let title):
            state.title = title
            return .persistTitle(title)
        case .saveTapped:
            state.isSaving = true
            return .save(title: state.title)
        case .saved:
            state.isSaving = false
            return nil
        }
    }

    override func handle(_ effect: Effect) async {
        switch effect {
        case .persistTitle(let title):
            await updateStore { $0.draftTitle = title }
        case .save(let title):
            try? await api.save(title)
            await updateStore { $0.entries.append(Entry(title: title)) }
            send(.saved)
        }
    }
}
```

### 3. View

```swift
struct EntryView: ContextualView {
    @State var viewModel: EntryViewModel

    init(_ context: EntryContext) {
        _viewModel = .init(initialValue: .init(context))
    }

    var body: some View {
        Form {
            TextField("Title", text: bindTo(\.title) { .titleChanged($0) })

            Button("Save") {
                send(.saveTapped)
            }
            .disabled(state.isSaving)
        }
    }
}
```

### 4. Unit tests

```swift
import Testing
@testable import App

@Suite("EntryViewModel tests")
struct EntryViewModelTests {
    @Test("Reducer: titleChanged updates state and emits effect")
    func reducer_titleChanged_updatesState_andEmitsEffect() {
        var state = EntryState()
        let effect = EntryViewModel.respond(to: .titleChanged("Hello"), state: &state)

        #expect(state.title == "Hello")
        #expect(effect == .persistTitle("Hello"))
    }

    @Test("send(saveTapped) runs effect and updates store")
    @MainActor
    func send_saveTapped_runsEffectAndUpdatesStore() async {
        let context = EntryContext(initialState: .init(), api: .mockSuccess)
        let sut = EntryViewModel(context)

        _ = sut.send(.titleChanged("New entry"))
        if let task = sut.send(.saveTapped) {
            await task.value
        }

        let store = await context.store.state
        #expect(store.entries.last?.title == "New entry")
        #expect(sut.state.isSaving == false)
    }
}
```

## Rules

1. **`respond` is pure.** It's a `class func` with no `self`. It cannot touch the store, coordinator, or any service.
2. **All side effects live in `handle`.** Store writes go through `await updateStore { ... }`.
3. **Only `state` is observable.** Mark non-state stored properties on your view model with `@ObservationIgnored`.
4. **Context owns dependencies.** Coordinator, services, clients all live on the `StoreContext`, not the view model.
5. **Views dispatch, never mutate.** Call `send(...)` (or `viewModel.send(...)`) from actions and bindings; only `await` the returned task when you must wait for async effect completion.

## Requirements

- iOS 17.0+
- macOS 14.0+
- Swift 5.9+ / Xcode 15.0+

## Documentation

Full API reference: [den-ree.github.io/chiui/documentation/chiui](https://den-ree.github.io/chiui/documentation/chiui/).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See `LICENSE` for details.
