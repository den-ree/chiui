//
//  ContextualContext.swift
//  CIUA
//
//  Created by Den Ree on 04/04/2025.
//

import Foundation

/// A protocol that defines the context for managing application state.
///
/// The `StoreContext` protocol serves as a dependency injection container for the store,
/// providing a single source of truth for state management. It enforces the unidirectional
/// data flow pattern where all state changes must go through the store.
///
/// ## Overview
///
/// The context can be used at different levels of your application:
/// - **Global Level**: Managing application-wide state
/// - **Feature Level**: Managing state for specific features or modules
///
/// The context acts as a bridge between your application's views, view models, and the state.
/// It ensures that state changes are predictable and traceable by centralizing all modifications
/// through the store.
///
/// ## Usage
///
/// ### Global State Example
/// ```swift
/// struct AppContext: StoreContext {
///     typealias StoreState = AppStoreState
///
///     let store: ContextualStore<AppStoreState>
///
///     init(initialState: AppStoreState) {
///         self.store = ContextualStore(initialState: initialState)
///     }
/// }
/// ```
///
/// ### Feature State Example
/// ```swift
/// struct AuthContext: StoreContext {
///     typealias StoreState = AuthStoreState
///
///     let store: ContextualStore<AuthStoreState>
///
///     init(initialState: AuthStoreState) {
///         self.store = ContextualStore(initialState: initialState)
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Essentials
///
/// - ``StoreState``
/// - ``store``
///
/// ### Related Types
///
/// - ``ContextualStore``
/// - ``ContextualStoreState``
public protocol StoreContext: Sendable {
  /// The type of store state used by this context.
  ///
  /// This associated type must conform to ``ContextualStoreState`` and represents
  /// the structure of your state, whether it's global application state or
  /// feature-specific state.
  associatedtype StoreState: ContextualStoreState

  /// The store instance that manages the state.
  ///
  /// The store is responsible for:
  /// - Maintaining the current state
  /// - Processing state updates
  /// - Notifying observers of state changes
  ///
  /// All state modifications should be performed through this store to maintain
  /// the unidirectional data flow pattern.
  var store: ContextualStore<StoreState> { get }
}

