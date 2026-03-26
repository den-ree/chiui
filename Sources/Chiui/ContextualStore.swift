//
//  ContextualStore.swift
//  Chiui
//
//  Created by Den Ree on 04/04/2025.
//

@preconcurrency import Combine

/// An actor that manages application state with thread-safe access and change notifications.
///
/// `ContextualStore` serves as the source of truth in the data flow architecture.
/// It manages state and notifies subscribers of any changes, ensuring thread safety through
/// the actor model.
///
/// ## Overview
///
/// The store provides:
/// - Thread-safe state access and updates
/// - State change notifications
/// - Unidirectional data flow enforcement
///
/// ## Usage
///
/// ```swift
/// // Create a store
/// let store = ContextualStore(AppStoreState())
///
/// // Subscribe to changes
/// let subscription = await store.subscribe { old, new in
///     print("State changed from \(old) to \(new)")
/// }
///
/// // Update state
/// await store.update { state in
///     state.user = newUser
///     state.isAuthenticated = true
/// }
/// ```
///
/// ## Topics
///
/// ### Essentials
///
/// - ``state``
/// - ``init(_:)``
///
/// ### State Management
///
/// - ``update(state:)``
/// - ``subscribe(updates:)``
///
/// ### Related Types
///
/// - ``ContextualStoreState``
public actor ContextualStore<State: ContextualStoreState> {
  /// The current state of the store.
  ///
  /// This property is actor-isolated, ensuring thread-safe access to the state.
  /// All state modifications should be performed through the ``update(state:)`` method.
  public private(set) var state: State

  /// Subject that broadcasts state changes to subscribers.
  ///
  /// This subject is used internally to notify subscribers of state changes.
  /// It sends both the old and new state to allow subscribers to track changes.
  private let changesSubject = PassthroughSubject<(old: State?, new: State), Never>()

  /// Creates a new store instance with an initial state.
  ///
  /// - Parameter state: The initial state for the store
  public init(_ state: State) {
    self.state = state
  }
}

/// Supporting updates and subscription methods
extension ContextualStore {
  /// Subscribes to state updates from the store.
  ///
  /// This method establishes a reactive connection between the store and subscribers.
  /// It immediately sends the current state and then notifies of any subsequent changes.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// let subscription = await store.subscribe { old, new in
  ///     if let old = old {
  ///         print("State changed from \(old) to \(new)")
  ///     } else {
  ///         print("Initial state: \(new)")
  ///     }
  /// }
  /// ```
  ///
  /// - Parameter updates: A closure that receives the old and new state. The old state will be `nil` for the initial update.
  /// - Returns: A cancellable subscription object that should be retained to keep the subscription active.
  func subscribe(updates: @escaping @Sendable ((old: State?, new: State)) -> Void) -> AnyCancellable {
    let result = changesSubject.sink { old, new in
      updates((old: old, new: new))
    }
    updates((nil, state))
    return result
  }

  /// Updates the store's state using the provided mutation block.
  ///
  /// This is the primary method for changing state in the data flow pattern.
  /// It ensures thread safety and notifies all subscribers of the change.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// await store.update { state in
  ///     state.user = newUser
  ///     state.isAuthenticated = true
  /// }
  /// ```
  ///
  /// - Parameter block: A closure that modifies the current state. The state is passed as an `inout` parameter.
  public func update(state block: @Sendable (inout State) -> Void) {
    let oldState = state
    block(&state)

    if oldState != state {
      changesSubject.send((old: oldState, new: state))
    }
  }
}
