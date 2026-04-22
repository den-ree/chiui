//
//  ContextualView.swift
//  Chiui
//
//  Created by Den Ree on 04/04/2025.
//

import SwiftUI

/// A protocol that defines a base view with an associated view model for state management.
///
/// `ContextualView` provides a structured way to create views bound to a view model,
/// enabling a clean separation between UI and business logic.
///
/// The view model owns the state (derived from `ContextualStore`) and the view wires SwiftUI
/// controls to that state via helpers like `bindTo` and `send`.
///
/// ## Overview
///
/// The protocol provides:
/// - Type-safe view model association
/// - Automatic state binding
/// - Two-way binding utilities that dispatch actions
///
/// ## Usage
///
/// ```swift
/// struct UserProfileView: ContextualView {
///     @State var viewModel: UserProfileViewModel
///
///     init(_ context: AppContext) {
///         _viewModel = .init(initialValue: .init(context))
///     }
///
///     var body: some View {
///         Form {
///             Section(header: Text("Profile")) {
///                 TextField("Name", text: bindTo(\.name) { .nameChanged($0) })
///                 TextField("Email", text: bindTo(\.email) { .emailChanged($0) })
///             }
///
///             Section {
///                 Button("Save") {
///                     send(.saveTapped)
///                 }
///                 .disabled(state.isSavingDisabled)
///             }
///         }
///         .navigationTitle(state.title)
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
/// - ``ViewModel``
/// - ``viewModel``
///
/// ### State Management
///
/// - ``state``
/// - ``bindTo(_:action:)``
///
/// ### Related Types
///
/// - ``StoreContext``
/// - ``ContextualViewState``
/// - ``ContextualViewModel``
public protocol ContextualView: View {
  /// The type of context that provides access to the store.
  associatedtype InjectedStoreContext: StoreContext

  /// The type of state used by this view.
  associatedtype ViewState: ContextualViewState

  /// The type of view model that manages this view's state and actions.
  associatedtype ViewModel: ContextualViewModel
  where
    ViewModel.ViewState == ViewState,
    ViewModel.InjectedStoreContext == InjectedStoreContext

  /// The view model instance that drives this view's behavior and state.
  var viewModel: ViewModel { get }
}

public extension ContextualView {
  /// Provides access to the view's current state.
  ///
  /// This computed property gives the view read-only access to the state
  /// that has been derived from the store by the view model.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// var body: some View {
  ///     VStack {
  ///         Text(state.name)
  ///         Text(state.email)
  ///     }
  /// }
  /// ```
  @MainActor var state: ViewModel.ViewState {
    viewModel.state
  }

  /// Creates a two-way `Binding` that reads a property from ``state`` and, on writes,
  /// dispatches an ``ContextualAction`` produced from the new value.
  ///
  /// This keeps SwiftUI controls on the Chiui unidirectional path: a write becomes an
  /// action, the reducer decides the resulting state, and `state` is updated through
  /// the normal `send` → `respond` flow.
  ///
  /// - Parameters:
  ///   - keyPath: The property in `ViewState` to bind.
  ///   - action: Builds the action to dispatch from the new bound value.
  /// - Returns: A `Binding` that reads from `state` and dispatches `action(newValue)` on write.
  ///
  /// ```swift
  /// TextField("Name", text: bindTo(\.name) { .nameChanged($0) })
  /// Toggle("Editing", isOn: bindTo(\.isEditing) { .setEditing($0) })
  /// ```
  @MainActor func bindTo<T>(
    _ keyPath: WritableKeyPath<ViewState, T>,
    action: @escaping (T) -> ViewModel.Action
  ) -> Binding<T> {
    Binding(
      get: { state[keyPath: keyPath] },
      set: { newValue in
        viewModel.send(action(newValue))
      }
    )
  }

  /// Dispatches an action synchronously through ``viewModel``.
  ///
  /// When the reducer emits an effect, ``ContextViewModel/handle(_:)`` runs asynchronously.
  /// Capture the returned task and `await task.value` only when effect completion must finish
  /// before subsequent work.
  @MainActor @discardableResult
  func send(_ action: ViewModel.Action) -> Task<Void, Never>? {
    viewModel.send(action)
  }
}
