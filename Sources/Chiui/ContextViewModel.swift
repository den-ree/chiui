//
//  ContextViewModel.swift
//  Chiui
//
//  Created by Den Ree on 04/04/2025.
//

import Observation
@preconcurrency import Combine

/// A protocol that defines the basic requirements for a view model in Chiui.
///
/// `ContextualViewModel` serves as the foundation for view models, requiring them to:
/// - Integrate with SwiftUI via ``ContextViewModel`` and `@Observable`
/// - Define their store context type
/// - Define their view state type
/// - Define an ``ContextualAction`` type that can represent store-driven updates
///
/// ## Overview
///
/// This protocol is the base requirement for all view models in the Chiui framework.
/// It ensures that view models can properly integrate with the store and handle state updates.
@MainActor
public protocol ContextualViewModel {
  /// The type of context that provides access to the store.
  associatedtype InjectedStoreContext: StoreContext

  /// The type of state used by this view model.
  associatedtype ViewState: ContextualViewState

  /// The type of action used to drive state transitions.
  associatedtype Action: ContextualAction

  /// The type of side effect produced by the reducer.
  associatedtype Effect

  /// Read-only state exposed to views.
  var state: ViewState { get }

  @discardableResult
  func send(_ action: Action) -> Task<(), Never>?
}

/// Marker protocol for action enums that participate in store-driven updates.
///
/// Declare `case storeChanged(YourStoreState)` on your action enum. The framework calls
/// ``Action/storeChanged(_:)`` (the synthesized enum case constructor) from the store
/// subscription, then ``respond(to:state:)`` handles `.storeChanged` like any other action.
///
/// Do not add a manual `static func storeChanged` — it conflicts with the `case storeChanged` name.
public protocol ContextualAction: Equatable, Sendable {
  associatedtype StoreState: ContextualStoreState

  static func storeChanged(_ state: StoreState) -> Self
}

/// A base view model class that integrates with a store and manages state.
///
/// `ContextViewModel` provides core functionality for Chiui's context-based unidirectional state
/// management in SwiftUI.
///
/// It implements:
/// - Unidirectional data flow from store state to view state (via ``Action/storeChanged(_:)`` → ``send(_:)`` → ``respond(to:state:)``)
/// - Reactive updates when store state changes
/// - Lifecycle management of subscriptions
/// - Local state mutation via ``updateState(_:)``
///
/// ## Overview
///
/// This class implements the core state management logic for views in the Chiui framework.
/// It handles the flow of data between the store and the view, ensuring that:
/// - Store updates are properly reflected in the view state
/// - State changes are properly tracked and managed
/// - Clean separation between local and global state
///
/// ## Usage
///
/// ```swift
/// enum Action: ContextualAction {
///     case storeChanged(AppStoreState)
///     case nameChanged(String)
/// }
///
/// override class func respond(to action: Action, state: inout ProfileState) -> Effect? {
///     switch action {
///     case .storeChanged(let store):
///         state.displayName = store.user?.name ?? ""
///         return nil
///     case .nameChanged(let name):
///         state.displayName = name
///         return .persist(name)
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Essentials
///
/// - ``StoreContext``
/// - ``ViewState``
/// - ``context``
/// - ``state``
///
/// ### State Management
///
/// - ``ContextualAction``
/// - ``send(_:)``
/// - ``respond(to:state:)``
/// - ``updateState(_:)``
/// - ``updateStore(_:)``
///
/// ### Related Types
///
/// - ``StoreContext``
/// - ``ContextualViewState``
/// - ``ContextualStateChange``
/// - ``ContextualStateChange``
@MainActor
@Observable
open class ContextViewModel<
  InjectedStoreContext: StoreContext,
  ViewState: ContextualViewState,
  Action: ContextualAction,
  Effect
>: ContextualViewModel where Action.StoreState == InjectedStoreContext.StoreState {
  /// The store context used by this view model
  @ObservationIgnored
  public let context: InjectedStoreContext

  /// Set of cancellables to manage subscriptions
  @ObservationIgnored
  private var cancellables = Set<AnyCancellable>()

  @ObservationIgnored
  nonisolated(unsafe) private var storeUpdateTask: Task<Void, Never>?
  @ObservationIgnored
  nonisolated(unsafe) private var connectTask: Task<Void, Never>?

  @ObservationIgnored
  private var hasInitialState: Bool = true

  /// The only observable property. SwiftUI re-renders only when `body` reads
  /// a value from `state` and that value changes.
  public fileprivate(set) var state: ViewState

  /// Creates a new view model instance with the given store context
  /// - Parameter context: The store context to use for state management
  public init(_ context: InjectedStoreContext) {
    self.context = context
    self.state = .init()

    connectTask = Task { [weak self] in
      let subscription = await context.store.subscribe { [weak self] _, new in
        self?.storeUpdateTask?.cancel()
        self?.storeUpdateTask = Task { @MainActor [weak self] in
          guard let self else { return }
          guard !Task.isCancelled else { return }
          let effectTask = self.send(.storeChanged(new))
          if let effectTask {
            await withTaskCancellationHandler {
              await effectTask.value
            } onCancel: {
              effectTask.cancel()
            }
          }
        }
      }
      self?.cancellables.insert(subscription)
    }
  }

  deinit {
    connectTask?.cancel()
    storeUpdateTask?.cancel()
  }

  /// Sends an action into the view model state machine.
  ///
  /// The reducer (`respond`) mutates local view state synchronously and may emit an effect.
  /// If an effect is produced, ``handle(_:)`` runs asynchronously and this method returns the task
  /// that runs it. Otherwise returns `nil`. Callers should `await task.value` only when they need
  /// deterministic completion after effect work (tests, sequencing).
  ///
  /// - Parameter action: The action to process.
  /// - Returns: A task representing async effect handling, or `nil` when no effect was emitted.
  @discardableResult
  public func send(_ action: Action) -> Task<(), Never>? {
    var effect: Effect?
    _ = updateState { state in
      effect = Self.respond(to: action, state: &state)
    }

    if let effect {
      let task = Task {
        await handle(effect)
      }

      return task
    }

    return nil
  }

  /// Pure reducer for handling actions and mutating view state.
  ///
  /// - Parameters:
  ///   - action: The incoming action.
  ///   - state: Mutable view state.
  /// - Returns: Optional effect to run after state update.
  open class func respond(to action: Action, state: inout ViewState) -> Effect? {
    nil
  }

  /// Runs asynchronous side effects emitted by `respond(to:state:)`.
  ///
  /// Override in subclasses to perform async follow-up work such as store updates,
  /// network calls, analytics, or navigation.
  ///
  /// - Parameter effect: Effect emitted by the reducer.
  open func handle(_ effect: Effect) async {}

  /// Updates the global store's state using a mutation block
  ///
  /// - Parameter block: A closure that modifies the store's state
  ///
  public func updateStore(
    _ block: @escaping @Sendable (inout InjectedStoreContext.StoreState) -> Void
  ) async {
    await context.store.update(state: block)
  }

  /// Mutates the view's local state by computing a `ContextualStateChange`.
  ///
  /// This method is unidirectional: it computes `oldState`/`newState`, updates `state` only when
  /// values actually changed, and returns mutation metadata for optional follow-up decisions.
  ///
  /// - Parameter block: A closure that mutates a copy of the current `ViewState`.
  /// - Returns: A `ContextualStateChange` describing the state transition.
  @discardableResult
  public func updateState(_ block: (inout ViewState) -> Void) -> ContextualStateChange<ViewState> {
    let oldState = state
    var newState = state
    block(&newState)

    let change = ContextualStateChange(oldState: oldState, newState: newState, isInitial: hasInitialState)

    if change.hasChanged {
      state = change.newState
      hasInitialState = false
    }

    return change
  }

  /// Reads a scoped value from the current view state and performs async work with it.
  ///
  /// Use this when you need to snapshot derived data from `state` and do async work without
  /// leaking `ViewState` mutations outside of the view model.
  ///
  /// - Parameters:
  ///   - scopeBlock: Maps the current `ViewState` into a smaller value for the async work.
  ///   - block: Async closure executed with the scoped value.
  /// - Returns: `Void`.
  public func scopeState<T>(_ scopeBlock: @escaping (ViewState) -> T, _ block: @escaping (T) async -> Void) async {
    await block(scopeBlock(state))
  }

  /// Subscribes to a cancellable and stores it for lifecycle management
  ///
  /// This method ensures that subscriptions are properly managed and cleaned up
  /// when the view model is deallocated.
  ///
  /// - Parameter cancelable: The cancellable to store
  public func subscribeOn(_ cancelable: AnyCancellable) {
    cancelable.store(in: &cancellables)
  }
}
