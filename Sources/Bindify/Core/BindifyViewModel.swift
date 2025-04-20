//
//  BindifyViewModel.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

import Combine

public protocol BindifyStatableViewModel {
  associatedtype State: BindifyLocalState

  var state: State { get }
}


public protocol BindifyActionableViewModel {
  associatedtype Action: Equatable

  @MainActor func onAction(_ action: Action)
}

/// A base view model class that integrates with a store and manages state.
///
/// `BindifyViewModel` provides core functionality for:
/// - Store state management and mapping
/// - State change notifications
///
open class BindifyViewModel<StoreContext: BindifyContext, ViewState: BindifyLocalState>: ObservableObject, BindifyStatableViewModel {
  /// Set of cancellables to manage subscriptions
  fileprivate var cancellables = Set<AnyCancellable>()

  /// The store context used by this view model
  public let context: StoreContext

  /// The current state of the view model
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

  /// - Parameter block: A closure that modifies the current state
  @MainActor public func updateState(_ block: @escaping (inout ViewState) -> Void) {
    updateState(block, trigger: .localUpdate)
  }

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

  /// Updates the global store's state using a mutation block
  ///
  /// - Parameter block: A closure that modifies the store's state
  public func updateStore(_ block: @escaping (inout StoreContext.StoreState) -> Void) {
    Task {
      await context.store.update(state: block)
    }
  }

  open func scopeStoreOnChange(_ storeState: StoreContext.StoreState) -> ViewState {
    fatalError(#function + " must be overridden")
  }

  @MainActor
  open func onStateWillChange(_ change: BindifyStateChange<ViewState>) {}

  @MainActor
  open func onStateDidChange(_ change: BindifyStateChange<ViewState>) async {}

  /// Subscribes to a cancellable and stores it for lifecycle management
  ///
  /// - Parameter cancelable: The cancellable to store
  public func subscribeOn(_ cancelable: AnyCancellable) {
    cancelable.store(in: &cancellables)
  }
}
