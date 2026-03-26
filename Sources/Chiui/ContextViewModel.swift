//
//  ContextViewModel.swift
//  Chiui
//
//  Created by Den Ree on 04/04/2025.
//

@preconcurrency import Combine

/// A protocol that defines the basic requirements for a view model in Chiui.
///
/// `ContextualViewModel` serves as the foundation for view models, requiring them to:
/// - Be observable objects for SwiftUI integration
/// - Define their store context type
/// - Define their view state type
///
/// ## Overview
///
/// This protocol is the base requirement for all view models in the Chiui framework.
/// It ensures that view models can properly integrate with the store and handle state updates.
public protocol ContextualViewModel: ObservableObject {
  /// The type of context that provides access to the store.
  associatedtype InjectedStoreContext: StoreContext

  /// The type of state used by this view model.
  associatedtype ViewState: ContextualViewState
}

/// A base view model class that integrates with a store and manages state.
///
/// `ContextViewModel` provides core functionality for Chiui's context-based unidirectional state
/// management in SwiftUI.
///
/// It implements:
/// - Unidirectional data flow from store state to view state
/// - Reactive updates when store state changes
/// - Lifecycle management of subscriptions
/// - Fluent local state update API with async chaining
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
/// final class UserProfileViewModel: ContextViewModel<AppContext, UserProfileViewState> {
///     override func didStoreUpdate(_ storeState: AppContext.StoreState) async {
///         updateState { state in
///             state.name = storeState.userProfile.name
///             state.isSavingDisabled = storeState.userProfile.name.isEmpty
///         }
///     }
///
///     func updateName(_ name: String) {
///         updateState { state in
///             state.name = name
///         }.updateStore { change, storeState in
///             storeState.userProfile.name = change.newState.name
///         }
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
/// - ``viewState``
///
/// ### State Management
///
/// - ``didStoreUpdate(_:)``
/// - ``updateState(_:)``
/// - ``updateStore(_:)``
///
/// ### Related Types
///
/// - ``StoreContext``
/// - ``ContextualViewState``
/// - ``ContextualStateChange``
/// - ``ContextualStateSideEffect``
@MainActor
open class ContextViewModel<InjectedStoreContext: StoreContext, ViewState: ContextualViewState>: ContextualViewModel {
  /// The current view state
  public var state: ViewState { viewState }

  /// The store context used by this view model
  public let context: InjectedStoreContext

  /// Set of cancellables to manage subscriptions
  private var cancellables = Set<AnyCancellable>()

  private var storeUpdateTask: Task<Void, Never>?
  private var connectTask: Task<Void, Never>?

  private var hasInitialState: Bool = true

  /// The current read-only state derived from the store state, specifically scoped for the view
  @Published fileprivate(set) var viewState: ViewState

  /// Creates a new view model instance with the given store context
  /// - Parameter context: The store context to use for state management
  public init(_ context: InjectedStoreContext) {
    self.context = context
    self.viewState = .init()

    connectTask = Task { [weak self] in
      let subscription = await context.store.subscribe { [weak self] _, new in
        Task { @MainActor [weak self] in
          self?.storeUpdateTask?.cancel()
          self?.storeUpdateTask = Task { [weak self] in
            guard let self else { return }
            await self.didStoreUpdate(new)
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

  /// Called when the store state has been updated
  ///
  /// This is the core mapping function that defines how the view state is derived from the store state.
  /// It should be pure and deterministic - the same store state should always produce the same view state.
  ///
  /// ## Overview
  ///
  /// This method is called whenever the store state changes and should:
  /// - Map relevant store state to view state using `updateState`
  /// - Handle any derived state calculations
  /// - Maintain UI-specific state
  ///
  /// ## Usage
  ///
  /// ```swift
  /// override func didStoreUpdate(_ storeState: AppContext.StoreState) async {
  ///     updateState { state in
  ///         state.name = storeState.userProfile.name
  ///         state.isSavingDisabled = storeState.userProfile.name.isEmpty
  ///     }
  /// }
  /// ```
  ///
  /// - Parameter storeState: The current store state
  nonisolated open func didStoreUpdate(
    _ storeState: InjectedStoreContext.StoreState
  ) async {
    // Default implementation does nothing
  }

  /// Updates the global store's state using a mutation block
  ///
  /// - Parameter block: A closure that modifies the store's state
  ///
  /// - Returns: A task that completes when the store update has been applied.
  @discardableResult
  public func updateStore(
    _ block: @escaping @Sendable (inout InjectedStoreContext.StoreState) -> Void
  ) -> Task<Void, Never> {
    Task {
      await context.store.update(state: block)
    }
  }

  @discardableResult
  /// Mutates the view's local state by computing a `ContextualStateChange`.
  ///
  /// This method is unidirectional: it computes `oldState`/`newState`, updates `state` only when
  /// values actually changed, and returns a side-effect handle you can chain with `then(_:)`.
  ///
  /// - Important: You can check `change.hasChanged` inside the `then` block to avoid performing
  ///   work when the mutation does not actually change values.
  ///
  /// - Parameter block: A closure that mutates a copy of the current `ViewState`.
  /// - Returns: A `ContextualStateSideEffect` that carries the computed state change.
  public func updateState(_ block: (inout ViewState) -> Void) -> ContextualStateSideEffect<ViewState> {
    let oldState = viewState
    var newState = viewState
    block(&newState)

    let change = ContextualStateChange(oldState: oldState, newState: newState, isInitial: hasInitialState)

    if change.hasChanged {
      viewState = change.newState
      hasInitialState = false
    }

    return .init(change: change)
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
    await block(scopeBlock(viewState))
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
