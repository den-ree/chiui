# ``Chiui``

A modern state management solution for Swift applications with flexible side effects.

## Overview

Chiui is a lightweight, type-safe state management library that provides unidirectional data flow with flexible side effect handling. It combines Swift's actor model with Combine to deliver predictable state management and reactive UI updates.

## Core Components

### State Management

- ``ContextualStore`` - Thread-safe actor-based store for application state
- ``ContextualState`` - Base protocol for all state types
- ``ContextualStoreState`` - Protocol for global store state
- ``ContextualViewState`` - Protocol for local view state

### View Integration

- ``ContextualView`` - SwiftUI view wrapper with automatic store integration
- ``ContextViewModel`` - Reactive view model with flexible side effects
- ``StoreContext`` - Environment context for store access
- ``ContextualStateSideEffect`` - Chainable side effect system

## Key Features

### Flexible Side Effects

Chiui's `then()` API provides powerful chaining for state updates:

```swift
// Update state with side effects
viewModel.updateState { state in
    state.name = newName
    state.isLoading = true
}.then { change in
    // Update global store
    await context.store.update { storeState in
        storeState.userProfile.name = change.newState.name
    }
    
    // Track analytics
    analytics.track("name_updated", properties: [
        "old_name": change.oldState.name,
        "new_name": change.newState.name
    ])
    
    // Make API call
    await api.updateUserProfile(name: change.newState.name)
}
```

### Synchronous Side Effects

For immediate operations, use the `wait` variant:

```swift
viewModel.updateState { state in
    state.isValid = isValidInput(state.input)
}.then(wait: { change in
    if change.newState.isValid {
        await validateOnServer(change.newState.input)
    }
})
```

## Getting Started

### 1. Define Your States

```swift
// Global store state
struct AppStoreState: ContextualStoreState {
    var user: User?
    var settings: AppSettings
    var isAuthenticated: Bool = false
}

// Local view state
struct ProfileViewState: ContextualViewState {
    var displayName: String = ""
    var isEditing: Bool = false
    var isSaving: Bool = false
    var validationError: String?
    
    init() {} // Required empty initializer
}
```

### 2. Create Store and Context

```swift
// Create store
let store = ContextualStore(AppStoreState(settings: .default))

// Create context
let context = AppContext(store: store)
```

### 3. Implement View Model

```swift
final class ProfileViewModel: ContextViewModel<AppContext, ProfileViewState> {
    override func didStoreUpdate(_ storeState: AppStoreState) async {
        updateState { viewState in
            viewState.displayName = storeState.user?.name ?? ""
            viewState.isSaving = false
        }
    }
    
    func updateName(_ name: String) {
        updateState { state in
            state.displayName = name
            state.validationError = validateName(name)
        }.then { change in
            guard change.newState.validationError == nil else { return }
            
            // Update global state
            await context.store.update { storeState in
                storeState.user?.name = change.newState.displayName
            }
            
            // Save to backend
            await saveUserProfile(name: change.newState.displayName)
        }
    }
    
    func startEditing() {
        updateState { state in
            state.isEditing = true
        }
    }
}
```

### 4. Use in SwiftUI

```swift
struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    
    init(context: AppContext) {
        self._viewModel = StateObject(wrappedValue: ProfileViewModel(context))
    }
    
    var body: some View {
        VStack {
            if viewModel.state.isEditing {
                TextField("Name", text: .constant(viewModel.state.displayName))
                    .onSubmit {
                        viewModel.updateName(viewModel.state.displayName)
                    }
            } else {
                Text(viewModel.state.displayName)
                    .onTapGesture {
                        viewModel.startEditing()
                    }
            }
            
            if let error = viewModel.state.validationError {
                Text(error).foregroundColor(.red)
            }
        }
    }
}
```

## Advanced Patterns

### Multiple Side Effects

Handle multiple operations within a single `then` block:

```swift
viewModel.updateState { state in
    state.selectedItems = newSelection
}.then { change in
    // Immediate UI feedback
    hapticFeedback.selectionChanged()
    
    // Background analytics
    analytics.track("selection_changed", count: change.newState.selectedItems.count)
    
    // Async store update
    await context.store.update { storeState in
        storeState.lastSelection = change.newState.selectedItems
    }
}
```

### Conditional Side Effects

```swift
viewModel.updateState { state in
    state.searchText = query
}.then { change in
    // Only search if query is long enough
    guard change.newState.searchText.count >= 3 else { return }
    
    await performSearch(query: change.newState.searchText)
}
```

## Requirements

- iOS 16.0+
- macOS 13.0+
- Swift 5.9+
- Xcode 15.0+

