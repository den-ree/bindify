//
//  BindifyView.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

import SwiftUI

/// A protocol that defines a view that works with a store context
///
/// Use this protocol when your view needs access to a global store through a context object
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
public protocol BindifyView: View {
  /// The type of view model associated with this view
  associatedtype ViewModel: ObservableObject

  /// The view model instance that drives this view's behavior and state
  var viewModel: ViewModel { get }
}

// MARK: - VIEW EXTENSION

/// Extensions for base view <-> view model communication

public extension BindifyView where ViewModel: BindifyActionableViewModel {
  @MainActor func onAction(_ action: ViewModel.Action) {
    viewModel.onAction(action)
  }
}

public extension BindifyView where ViewModel: BindifyStatableViewModel {
  var state: ViewModel.State {
    viewModel.state
  }

  /// Refreshes the view state by deriving it from the store state
  /// - Parameter trigger: The event that triggered the refresh
  @MainActor
  func refreshState(trigger: BindifyStateChange<ViewModel.State>.Trigger = .localUpdate) {
    let oldState = state
    let newState = viewModel.scopeState()
    
    let change = BindifyStateChange(trigger: trigger, oldState: oldState, newState: newState)
    
    guard change.hasChanged || change.isInitial else { return }
    
    viewModel.onStateWillChange(change)
    viewModel.state = newState
    
    Task {
      await viewModel.onStateDidChange(change)
    }
  }
}
