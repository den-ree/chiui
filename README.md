<h1><img src="assets/icon.png" alt="Chiui logo" width="28" /> Chiui</h1>

Context-based unidirectional state management for SwiftUI

![CI](https://github.com/den-ree/chiui/actions/workflows/ci.yml/badge.svg)
![Release](https://github.com/den-ree/chiui/actions/workflows/release.yml/badge.svg)

Simple, lightweight updates for SwiftUI, designed for Swift 6 concurrency and unidirectional UI architecture.

## Features

- **State Management**: Simple and efficient state management using a store-based approach
- **View Models**: Built-in support for view models with state transformation
- **Type Safety**: Fully type-safe implementation
- **SwiftUI Integration**: Seamless integration with SwiftUI views
- **Testability**: Easy to test with clear separation of concerns

## Requirements

- iOS 16.0+ / macOS 13.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/den-ree/chiui", from: "1.0.0")
]
```

## Usage

Chiui enables a clean separation of local (view) state and global (store) state, with support for side effects. Here are the recommended patterns:

### 1. Update Local View State

Use `updateState` to update only the view's local state:

```swift
@MainActor
func updateTitle(_ title: String) {
    updateState { state in
        state.title = title
    }
}
```

### 2. Update the Store

Use `updateStore` to mutate the global store state:

```swift
@MainActor
func selectEntry(_ entry: Entry) {
    updateStore { storeState in
        storeState.selectedEntry = entry
    }
}
```

### 3. Combine State Update and Store Update with Side Effects

Chain `.then(_:)` after `updateState` to perform async work and update the store in response to a local state change:

```swift
@MainActor
func finishEditing(save: Bool) async {
    guard save else {
        await updateState { state in
          state.isEditing = false
        }.then { [weak self] _ in
            self?.updateStore { $0.selectedEntry = nil }
        }
        return
    }

    await updateState { state in
        state.savingStatus = .saving
    }.then { [weak self] change in
        guard let self, change.hasChanged else { return }
        // Simulate async save
        try? await Task.sleep(for: .seconds(2))
        self.updateStore { $0.selectedEntry = nil }
    }
}
```

### 4. Get State for Store Update

Use `scopeState` to snapshot the latest view state and then update the store. This is useful when you need to synchronize the store with the most recent view state, for example after a user action or form submission.

```swift
@MainActor
func finishEditing() {
  Task {
    await scopeState({ $0 }) { [weak self] state in
      self?.updateStore { $0.selectedEntry = state.entry }
    }
  }
}
```

### 5. Use in SwiftUI Views

ContextualView provides helpers for binding view state to SwiftUI controls:

```swift
struct EntryView: ContextualView {
    @StateObject var viewModel: EntryViewModel
    // ...
    var body: some View {
        TextField("Title", text: bindTo(\.title) { viewModel.updateTitle($0) })
        Button("Save") { viewModel.finishEditing(save: true) }
    }
}
```

## Documentation

For detailed documentation, including:
- Complete API reference
- Architecture overview
- Best practices
- Testing guidelines
- Advanced usage examples

Please visit our [Documentation](https://den-ree.github.io/chiui/documentation/chiui/).

Hosted DocC can be published with the `Publish DocC` workflow to GitHub Pages.

## Why Chiui

- Local view state and global store state are clearly separated.
- Async side effects are explicit and chainable through `then(_:)`.
- Store to view mapping is centralized in `didStoreUpdate(_:)`.
- Works naturally with SwiftUI via `ContextualView` bindings.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and PR guidance.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
