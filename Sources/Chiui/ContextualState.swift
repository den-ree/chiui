//
//  ContextualState.swift
//  Chiui
//
//  Created by Den Ree on 04/04/2025.
//

/// A protocol that defines the base requirements for all state types in Chiui.
///
/// All states in Chiui must conform to this protocol, which ensures they are:
/// - Value types that can be compared for equality
/// - Thread-safe for concurrent access
///
/// ## Overview
///
/// The `ContextualState` protocol serves as the foundation for all state management in Chiui.
/// It enforces immutability and thread safety, which are crucial for predictable state management
/// in a unidirectional data flow architecture.
///
/// ## Usage
///
/// ```swift
/// struct UserState: ContextualState {
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
/// - ``ContextualStoreState``
/// - ``ContextualViewState``
public protocol ContextualState: Equatable & Sendable {}

/// A protocol that defines the state for a store in Chiui.
///
/// The `ContextualStoreState` represents the source of truth for your application or feature.
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
/// struct AppStoreState: ContextualStoreState {
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
/// - ``ContextualState``
/// - ``ContextualViewState``
public protocol ContextualStoreState: ContextualState {}

/// A protocol that defines the state for a view in Chiui.
///
/// The `ContextualViewState` represents the UI-specific state that can be updated in two ways:
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
/// struct UserViewState: ContextualViewState {
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
/// - ``ContextualState``
/// - ``ContextualStoreState``
public protocol ContextualViewState: ContextualState {
  /// Creates an empty state instance.
  ///
  /// This initializer is required to support state initialization before
  /// any data is available from the store.
  init()
}

/// A structure that represents a view state change with metadata.
///
/// `ContextualStateChange` tracks the lifecycle of a state mutation attempt, including:
/// - The previous view state (`oldState`)
/// - The proposed view state (`newState`)
/// - Whether this is the first time the view state has been set (`isInitial`)
/// - Whether the values actually changed (`hasChanged`)
///
/// ## Overview
///
/// This type is used by [`ContextViewModel.updateState(_:)`](ContextViewModel/updateState(_:)) to provide
/// enough context for follow-up side effects (analytics, async work, store synchronization, navigation, etc.).
///
/// ## Usage
///
/// ```swift
/// let change = ContextualStateChange(
///     oldState: previousState,
///     newState: currentState,
///     isInitial: false
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
/// - ``oldState``
/// - ``newState``
/// - ``isInitial``
/// - ``hasChanged``
public struct ContextualStateChange<State: ContextualState>: Equatable, Sendable {
  /// The state before the change occurred.
  public let oldState: State

  /// The state after the change occurred.
  public let newState: State

  /// Only true when the state has been updated first time
  public let isInitial: Bool

  /// Whether the state actually changed values.
  public var hasChanged: Bool { oldState != newState }
}
