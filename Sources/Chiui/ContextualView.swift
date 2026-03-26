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
/// controls to that state via helpers like `bindTo`.
///
/// ## Overview
///
/// The protocol provides:
/// - Type-safe view model association
/// - Automatic state binding
/// - Two-way binding utilities
///
/// ## Usage
///
/// ```swift
/// struct UserProfileView: ContextualView {
///     @StateObject var viewModel: UserProfileViewModel
///
///     init(_ context: AppContext) {
///         _viewModel = .init(wrappedValue: .init(context))
///     }
///
///     var body: some View {
///         Form {
///             Section(header: Text("Profile")) {
///                 TextField("Name", text: bindTo(\.name) { viewModel.updateName($0) })
///                 TextField("Email", text: bindTo(\.email) { viewModel.updateEmail($0) })
///             }
///
///             Section {
///                 Button("Save") {
///                     viewModel.save()
///                 }
///                     .disabled(state.isSavingDisabled)
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

public extension ContextualView where ViewModel: ContextViewModel<InjectedStoreContext, ViewState> {
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
    viewModel.viewState
  }

  /// Creates a two-way `Binding` to a specific property inside `ViewState`.
  ///
  /// - Parameters:
  ///   - keyPath: The property in `ViewState` to bind.
  ///   - onSet: Called whenever SwiftUI writes a new value into the binding.
  ///            In practice, this usually forwards to a view-model method that mutates
  ///            state via `updateState(_:)`.
  /// - Returns: A `Binding` that reads from `state` and forwards updates to `onSet`.
  @MainActor func bindTo<T>(
    _ keyPath: WritableKeyPath<ViewState, T>,
    action onSet: @escaping (T) -> Void
  ) -> Binding<T> {
    Binding(
      get: { state[keyPath: keyPath] },
      set: { newValue in
        onSet(newValue)
      }
    )
  }
}
