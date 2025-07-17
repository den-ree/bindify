//
//  BindifyView.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

import SwiftUI

/// A protocol that defines a base view with an associated view model for state management.
///
/// `BindifyView` provides a structured way to create views that are bound to a view model,
/// enabling a clean separation between UI and business logic. The view model transforms
/// store state into view-specific state and handles user actions.
///
/// ## Overview
///
/// The protocol provides:
/// - Type-safe view model association
/// - Automatic state binding
/// - Action dispatching
/// - Two-way binding utilities
///
/// ## Usage
///
/// ```swift
/// struct UserProfileView: BindifyView {
///     @StateObject var viewModel: UserProfileViewModel
///
///     init(_ context: AppContext) {
///         _viewModel = .init(wrappedValue: .init(context))
///     }
///
///     var body: some View {
///         Form {
///             Section(header: Text("Profile")) {
///                 TextField("Name", text: bindTo(\.name) { .updateName($0) })
///                 TextField("Email", text: bindTo(\.email) { .updateEmail($0) })
///             }
///
///             Section {
///                 Button("Save") { onAction(.save) }
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
/// - ``Action``
/// - ``ViewModel``
/// - ``viewModel``
///
/// ### State Management
///
/// - ``state``
/// - ``onAction(_:)``
/// - ``bindTo(_:action:)``
///
/// ### Related Types
///
/// - ``BindifyContext``
/// - ``BindifyViewState``
/// - ``BindifyViewModel``
public protocol BindifyView: View {
  /// The type of context that provides access to the store.
  associatedtype StoreContext: BindifyContext

  /// The type of state used by this view.
  associatedtype ViewState: BindifyViewState

  /// The type of view model that manages this view's state and actions.
  associatedtype ViewModel: BindifiableViewModel where ViewModel.ViewState == ViewState, ViewModel.StoreContext == StoreContext

  /// The view model instance that drives this view's behavior and state.
  var viewModel: ViewModel { get }
}

public extension BindifyView where ViewModel: BindifyViewModel<StoreContext, ViewState> {
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

  @MainActor func bindTo<T>(_ keyPath: WritableKeyPath<ViewState, T>, action onSet: @escaping (T) -> Void) -> Binding<T> {
    Binding(
      get: { state[keyPath: keyPath] },
      set: { newValue in
        onSet(newValue)
      }
    )
  }
}

