//
//  BindifyViewModel.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

import Combine

public protocol BindifiableViewModel: ObservableObject {
  associatedtype StoreContext: BindifyContext
  associatedtype ViewState: BindifyViewState
  associatedtype Action: Equatable
}

/// A base view model class that integrates with a store and manages state.
///
/// `BindifyViewModel` provides core functionality for:
/// - Unidirectional data flow from store state to view state
/// - Store state updates through actions
/// - Reactive updates when store state changes
///
open class BindifyViewModel<StoreContext: BindifyContext, ViewState: BindifyViewState, Action: Equatable>: BindifiableViewModel {
  /// Set of cancellables to manage subscriptions
  private var cancellables = Set<AnyCancellable>()

  /// The store context used by this view model
  public let context: StoreContext

  /// The current read-only state derived from the store state, specifically scoped for the view
  @Published fileprivate(set) var viewState: ViewState

  /// Creates a new view model instance with the given store context
  /// - Parameter context: The store context to use for state management
  public init(_ context: StoreContext) {
    self.context = context
    self.viewState = .init()

    Task {
      await context.store.subscribe { [weak self] old, new in
        guard let self = self else { return }
        var newState = self.viewState
        self.scopeStateOnStoreChange(new, &newState)

        Task {
          await self.updateState({ $0 = newState }, trigger: old == nil ? .storeConnection : .storeUpdate)
        }
      }.store(in: &cancellables)
    }
  }

  deinit {
    cancellables.forEach { $0.cancel() }
    cancellables.removeAll()
  }

  /// The main entry point for handling actions
  /// 
  /// This method processes actions and updates state accordingly.
  /// It first updates the view state based on the action, then optionally updates the store.
  ///
  /// - Parameter action: The action to process
  @MainActor
  open func onAction(_ action: Action) {
    var newState = viewState
    let storeUpdate = scopeStateOnAction(action, &newState)
    updateState({ $0 = newState }, trigger: .actionUpdate)

    if let update = storeUpdate {
      Task {
        await context.store.update(state: update)
      }
    }
  }

  /// Scopes the action into state changes
  /// 
  /// This method handles both local view state changes and store state changes.
  /// It should be pure and deterministic - the same action and state should always produce the same changes.
  ///
  /// - Parameters:
  ///   - action: The action being processed
  ///   - newState: The current view state to be modified
  /// - Returns: Optional closure to update the store state
  open func scopeStateOnAction(
    _ action: Action,
    _ newState: inout ViewState
  ) -> ((inout StoreContext.StoreState) -> Void)? {
    // Default implementation does nothing
    return nil
  }

  /// Scopes the store state into the local view state
  /// 
  /// This is the core mapping function that defines how the view state is derived from the store state.
  /// It should be pure and deterministic - the same store state should always produce the same view state.
  ///
  /// - Parameters:
  ///   - storeState: The current store state
  ///   - newState: The view state to be modified
  open func scopeStateOnStoreChange(
    _ storeState: StoreContext.StoreState,
    _ newState: inout ViewState
  ) {
    fatalError(#function + " must be overridden")
  }

  /// Called just before the view state changes
  /// - Parameter change: Contains the old state, new state, and trigger type
  @MainActor
  open func onStateWillChange(_ change: BindifyStateChange<ViewState>) {}

  /// Called after the view state has changed
  /// - Parameter change: Contains the old state, new state, and trigger type
  @MainActor
  open func onStateDidChange(_ change: BindifyStateChange<ViewState>) async {}

  /// Subscribes to a cancellable and stores it for lifecycle management
  ///
  /// - Parameter cancelable: The cancellable to store
  public func subscribeOn(_ cancelable: AnyCancellable) {
    cancelable.store(in: &cancellables)
  }
}

private extension BindifyViewModel {
  /// Internal method to update the view state with lifecycle hooks
  /// 
  /// This method handles the state update process including:
  /// - Change detection
  /// - Lifecycle notifications (willChange/didChange)
  /// 
  /// - Parameters:
  ///   - block: A closure that modifies the view state
  ///   - trigger: The source that triggered this state update
  @MainActor func updateState(_ block: @escaping (inout ViewState) -> Void, trigger: BindifyStateChange<ViewState>.Trigger) {
    let oldState = viewState
    var newState = viewState
    block(&newState)

    let change = BindifyStateChange(trigger: trigger, oldState: oldState, newState: newState)

    guard change.hasChanged || change.isInitial else { return }

    onStateWillChange(change)

    viewState = change.newState

    Task {
      await onStateDidChange(change)
    }
  }
}
