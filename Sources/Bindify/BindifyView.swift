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

  /// The type of actions that can be dispatched by this view.
  associatedtype Action: BindifyAction

  /// The type of view model that manages this view's state and actions.
  associatedtype ViewModel: BindifiableViewModel where ViewModel.Action == Action, ViewModel.ViewState == ViewState, ViewModel.StoreContext == StoreContext

  /// The view model instance that drives this view's behavior and state.
  var viewModel: ViewModel { get }
}

public extension BindifyView where ViewModel: BindifyViewModel<StoreContext, ViewState, Action> {
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

  /// Dispatches an action to the view model.
  ///
  /// In the unidirectional data flow pattern, actions are the primary way to trigger state changes.
  /// The view dispatches actions to the view model, which processes them and updates the state.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// Button("Save") { onAction(.save) }
  /// Button("Delete") { onAction(.delete) }
  /// ```
  ///
  /// - Parameter action: The action to dispatch
  @MainActor func onAction(_ action: Action) {
    viewModel.send(action)
  }

  /// Creates a two-way binding between a view's state property and an action.
  ///
  /// This method is used to create SwiftUI bindings that automatically dispatch actions
  /// when the bound value changes. It's particularly useful for form fields and other
  /// interactive UI elements that need to update the view model's state.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// // Simple text field binding
  /// TextField("Title", text: bindTo(\.title) { .updateTitle($0) })
  ///
  /// // Toggle binding with optional action
  /// Toggle("Enabled", isOn: bindTo(\.isEnabled) { newValue in
  ///     newValue ? .enable : .disable
  /// })
  ///
  /// // Custom binding with validation
  /// TextField("Age", text: bindTo(\.age) { newValue in
  ///     guard let age = Int(newValue) else { return nil }
  ///     return .updateAge(age)
  /// })
  /// ```
  ///
  /// - Parameters:
  ///   - keyPath: A writable key path to the state property that should be bound
  ///   - onSet: A closure that takes the new value and returns an optional action to dispatch.
  ///            If the closure returns nil, no action will be dispatched.
  /// - Returns: A SwiftUI Binding that can be used with SwiftUI views
  @MainActor func bindTo<T>(_ keyPath: WritableKeyPath<ViewState, T>, action onSet: @escaping (T) -> Action?) -> Binding<T> {
    Binding(
      get: { state[keyPath: keyPath] },
      set: { newValue in
        if let action = onSet(newValue) {
          onAction(action)
        }
      }
    )
  }
}

