//
//  BindifyState.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

/// A protocol that defines the base requirements for all state types in the Bindify framework.
///
/// All states in Bindify must conform to this protocol, which ensures they are:
/// - Value types that can be compared for equality
/// - Thread-safe for concurrent access
///
/// ## Overview
///
/// The `BindifyState` protocol serves as the foundation for all state management in Bindify.
/// It enforces immutability and thread safety, which are crucial for predictable state management
/// in a unidirectional data flow architecture.
///
/// ## Usage
///
/// ```swift
/// struct UserState: BindifyState {
///     let id: String
///     let name: String
///     let isActive: Bool
/// }
/// ```
///
/// ## Topics
///
/// ### Related Types
///
/// - ``BindifyStoreState``
/// - ``BindifyViewState``
public protocol BindifyState: Equatable & Sendable {}

/// A protocol that defines the state for a store in the Bindify framework.
///
/// The `BindifyStoreState` represents the source of truth for your application or feature.
/// It should contain only the essential data that needs to be shared and persisted.
///
/// ## Overview
///
/// Store states should be:
/// - Minimal and focused on core data
/// - Serializable for persistence
/// - Thread-safe for concurrent access
///
/// ## Usage
///
/// ```swift
/// struct AppStoreState: BindifyStoreState {
///     var user: User?
///     var settings: Settings
///     var isAuthenticated: Bool
/// }
/// ```
///
/// ## Topics
///
/// ### Related Types
///
/// - ``BindifyState``
/// - ``BindifyViewState``
public protocol BindifyStoreState: BindifyState {}

/// A protocol that defines the state for a view in the Bindify framework.
///
/// The `BindifyViewState` represents the UI-specific state that can be updated in two ways:
/// 1. Derived from store state (for shared data)
/// 2. Updated through actions (for local UI state)
///
/// ## Overview
///
/// View states should:
/// - Contain both derived and local UI state
/// - Be updated through actions in a unidirectional flow
/// - Never be directly mutated outside of the view model
/// - Have a default empty initializer
///
/// ## Usage
///
/// ```swift
/// struct UserViewState: BindifyViewState {
///     // Derived from store state
///     var displayName: String
///     var isOnline: Bool
///     
///     // Local UI state
///     var isEditing: Bool
///     var selectedTab: Int
///     var lastSeen: String
///     
///     init() {
///         self.displayName = ""
///         self.isOnline = false
///         self.isEditing = false
///         self.selectedTab = 0
///         self.lastSeen = ""
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Essentials
///
/// - ``init()``
///
/// ### Related Types
///
/// - ``BindifyState``
/// - ``BindifyStoreState``
public protocol BindifyViewState: BindifyState {
    /// Creates an empty state instance.
    ///
    /// This initializer is required to support state initialization before
    /// any data is available from the store.
    init()
}

/// A protocol that defines the base requirements for all action types in the Bindify framework.
///
/// Actions in Bindify represent user interactions or system events that can trigger state changes.
/// They must be:
/// - Value types that can be compared for equality
/// - Thread-safe for concurrent access
///
/// ## Overview
///
/// The `BindifyAction` protocol serves as the foundation for all actions in Bindify.
/// It enforces immutability and thread safety, which are crucial for predictable state management
/// in a unidirectional data flow architecture.
///
/// ## Usage
///
/// ```swift
/// enum UserAction: BindifyAction {
///     case updateName(String)
///     case toggleActive
///     case save
/// }
/// ```
///
/// ## Topics
///
/// ### Related Types
///
/// - ``BindifyState``
/// - ``BindifyStateEvent``
public protocol BindifyAction: Equatable, Sendable {}

/// A structure that represents a state change event with metadata.
///
/// `BindifyStateChange` tracks the lifecycle of state changes, including:
/// - What triggered the change
/// - The previous state
/// - The new state
/// - Whether it's an initial state
/// - Whether the state actually changed
///
/// ## Overview
///
/// State changes can be triggered by:
/// - Initial store connection
/// - Store updates
/// - Local actions
///
/// ## Usage
///
/// ```swift
/// let change = BindifyStateChange(
///     trigger: .actionUpdate,
///     oldState: previousState,
///     newState: currentState
/// )
///
/// if change.hasChanged {
///     // Handle state update
/// }
/// ```
///
/// ## Topics
///
/// ### Essentials
///
/// - ``Trigger``
/// - ``trigger``
/// - ``oldState``
/// - ``newState``
/// - ``isInitial``
/// - ``hasChanged``
public struct BindifyStateChange<State: BindifyState>: Equatable, Sendable {
  /// The state before the change occurred.
  public let oldState: State

  /// The state after the change occurred.
  public let newState: State

  /// Only true when the state has been updated first time
  public let isInitial: Bool

  /// Whether the state actually changed values.
  public var hasChanged: Bool { oldState != newState }
}

public struct BindifyStateSideEffect<State: BindifyState>: Sendable {
  let change: BindifyStateChange<State>

  @MainActor
  public func then(_ block: @escaping @MainActor (BindifyStateChange<State>) async -> Void) async -> Void {
    await block(change)
  }
}
