//
//  BindifyViewModel.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

import Combine

/// Protocol defining a view model that provides a read-only state
public protocol BindifyStatableViewModel {
  associatedtype State: BindifyLocalState

  /// The read-only state derived from the global store state
  var state: State { get }
}

/// Protocol defining a view model that can respond to actions
public protocol BindifyActionableViewModel {
  associatedtype Action: Equatable

  /// Process an action to update the store state
  /// - Parameter action: The action to process
  @MainActor func onAction(_ action: Action)
}

/// A base view model class that integrates with a store and manages state.
///
/// `BindifyViewModel` provides core functionality for:
/// - Unidirectional data flow from store state to view state
/// - Store state updates through actions
/// - Reactive updates when store state changes
///
open class BindifyViewModel<StoreContext: BindifyContext, ViewState: BindifyLocalState>: ObservableObject, BindifyStatableViewModel {
  /// Set of cancellables to manage subscriptions
  fileprivate var cancellables = Set<AnyCancellable>()

  /// The store context used by this view model
  public let context: StoreContext

  /// The current read-only state of the view, derived from the store state
  @Published public private(set) var state: ViewState

  /// Creates a new view model instance with the given store context
  /// - Parameter context: The store context to use for state management
  public init(_ context: StoreContext) {
    self.context = context
    self.state = .init()

    Task {
      await context.store.subscribe { [weak self] old, new in
        guard let self = self else { return }
        let newState = self.scopeStoreOnChange(new)

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

  /// Updates the view state directly (consider using updateStore instead for unidirectional flow)
  /// - Parameter block: A closure that modifies the current view state
  @available(*, deprecated, message: "Use updateStore() to modify store state and let refreshState() derive the new view state")
  @MainActor public func updateState(_ block: @escaping (inout ViewState) -> Void) {
    updateState(block, trigger: .localUpdate)
  }

  /// Updates the global store's state using a mutation block
  /// 
  /// This is the preferred way to make state changes in the unidirectional data flow pattern.
  /// Changes to the store will automatically trigger view state updates.
  ///
  /// - Parameter block: A closure that modifies the store's state
  public func updateStore(_ block: @escaping (inout StoreContext.StoreState) -> Void) {
    Task {
      await context.store.update(state: block)
      // Note: Store updates will automatically trigger refreshState through the subscription
    }
  }

  /// Transforms the store state into a view state
  /// 
  /// This is the core mapping function that defines how the view state is derived from the store state.
  /// It should be pure and deterministic - the same store state should always produce the same view state.
  ///
  /// - Parameter storeState: The current store state
  /// - Returns: A new view state derived from the store state
  open func scopeStoreOnChange(_ storeState: StoreContext.StoreState) -> ViewState {
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

  /// Manually refreshes the view state by deriving it from the current store state
  /// 
  /// This method is useful when you need to force a view state refresh without changing the store.
  /// In the unidirectional data flow pattern, this should rarely be needed as store changes
  /// automatically trigger view state updates.
  /// 
  /// - Returns: A task that completes when the state has been refreshed
  @MainActor
  public func refreshState() async {
    let currentStoreState = await context.store.state
    let newState = self.scopeStoreOnChange(currentStoreState)

    await self.updateState({ $0 = newState }, trigger: .localUpdate)
  }

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
    let oldState = state
    var newState = state
    block(&newState)

    let change = BindifyStateChange(trigger: trigger, oldState: oldState, newState: newState)

    guard change.hasChanged || change.isInitial else { return }

    onStateWillChange(change)

    state = change.newState

    Task {
      await onStateDidChange(change)
    }
  }
}
