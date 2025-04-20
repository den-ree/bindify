//
//  BindifyView.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

import SwiftUI

/// A protocol that defines a view that works with a store context
///
/// Use this protocol when your view needs access to a global store through a context object.
/// Views implementing this protocol participate in the unidirectional data flow pattern,
/// where data flows from the store to the view model to the view.
public protocol BindifyStateView: BindifyView {
  /// The type of store context this view uses
  associatedtype StoreContext: BindifyContext

  /// Creates a new view instance with the given store context
  /// - Parameter context: The store context to use for this view
  init(_ context: StoreContext)
}

/// A protocol that defines a base view with an associated observable view model
///
/// Implement this protocol to create views that are bound to a view model conforming to `ObservableObject`
/// The view model serves as the intermediary between the global store and the view,
/// transforming store state into view-specific state.
public protocol BindifyView: View {
  /// The type of view model associated with this view
  associatedtype ViewModel: ObservableObject

  /// The view model instance that drives this view's behavior and state
  var viewModel: ViewModel { get }
}

// MARK: - VIEW EXTENSION

/// Extensions for base view <-> view model communication

/// Extension for dispatching actions to the view model
public extension BindifyView where ViewModel: BindifyActionableViewModel {
  /// Dispatches an action to the view model
  /// 
  /// In the unidirectional data flow pattern, actions are the primary way to trigger state changes.
  /// The view dispatches actions to the view model, which processes them and updates the store.
  ///
  /// - Parameter action: The action to dispatch
  @MainActor func onAction(_ action: ViewModel.Action) {
    viewModel.onAction(action)
  }
}

/// Extension for accessing view state from the view model
public extension BindifyView where ViewModel: BindifyStatableViewModel {
  /// Provides access to the derived view state
  ///
  /// This computed property gives the view read-only access to the state
  /// that has been derived from the global store by the view model.
  var state: ViewModel.State {
    viewModel.state
  }
}
