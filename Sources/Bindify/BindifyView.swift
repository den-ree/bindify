//
//  BindifyView.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

import SwiftUI

/// A protocol that defines a base view with an associated observable view model
///
/// Implement this protocol to create views that are bound to a view model conforming to `ObservableObject`
/// The view model serves as the intermediary between the global store and the view,
/// transforming store state into view-specific state.
public protocol BindifyView: View {
  /// The type of view model associated with this view
  associatedtype StoreContext: BindifyContext
  associatedtype ViewState: BindifyViewState
  associatedtype Action: Equatable
  associatedtype ViewModel: BindifiableViewModel where ViewModel.Action == Action, ViewModel.ViewState == ViewState, ViewModel.StoreContext == StoreContext

  /// The view model instance that drives this view's behavior and state
  var viewModel: ViewModel { get }
}

public extension BindifyView where ViewModel: BindifyViewModel<StoreContext, ViewState, Action> {
  /// Provides access to the derived view state
  ///
  /// This computed property gives the view read-only access to the state
  /// that has been derived from the global store by the view model.
  @MainActor var state: ViewModel.ViewState {
    viewModel.viewState
  }

  /// Dispatches an action to the view model
  ///
  /// In the unidirectional data flow pattern, actions are the primary way to trigger state changes.
  /// The view dispatches actions to the view model, which processes them and updates the store.
  ///
  /// - Parameter action: The action to dispatch
  @MainActor func onAction(_ action: Action) {
    viewModel.onAction(action)
  }

  /// Creates a two-way binding between a view's state property and an action.
  ///
  /// This method is used to create SwiftUI bindings that automatically dispatch actions
  /// when the bound value changes. It's particularly useful for form fields and other
  /// interactive UI elements that need to update the view model's state.
  ///
  /// Example usage:
  /// ```swift
  /// TextField("Title", text: bindTo(\.title) { .updateTitle($0) })
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
