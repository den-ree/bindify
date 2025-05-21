//
//  BindifyStore.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

import Combine

/// An actor that manages a global state store with thread-safe access
///
/// `BindifyStore` serves as the single source of truth in the unidirectional data flow architecture.
/// It manages the global application state and notifies subscribers of any state changes.
/// The actor model ensures thread safety for all state operations.
public actor BindifyStore<State: BindifyStoreState> {
  /// The current state of the store
  private(set) var state: State

  /// Subject that broadcasts state changes to subscribers
  private let changesSubject = PassthroughSubject<(old: State?, new: State), Never>()

  /// Creates a new store instance with an initial state
  /// - Parameter state: The initial state for the store
  public init(_ state: State) {
    self.state = state
  }
}

/// Supporting updates and subscription methods
extension BindifyStore {
  /// Subscribes to state updates from the store
  /// 
  /// This is used to establish a reactive connection between the store and view models.
  /// In the unidirectional data flow pattern, this enables automatic propagation of state changes.
  ///
  /// - Parameter updates: A closure that receives the old and new state
  /// - Returns: A cancellable subscription object
  func subscribe(updates: @escaping ((old: State?, new: State)) -> Void) -> AnyCancellable {
    let result = self.changesSubject.sink(receiveValue: { old, new in
      updates((old: old, new: new))
    })

    updates((nil, state))

    return result
  }

  /// Updates the store's state using the provided mutation block
  /// 
  /// This is the primary method for changing state in the unidirectional data flow pattern.
  /// All state changes should flow through this method to ensure proper notification of subscribers.
  ///
  /// - Parameter block: A closure that modifies the current state
  func update(state block: (inout State) -> Void) {
    let oldState = state
    block(&state)

    if oldState != state {
      changesSubject.send((old: oldState, new: state))
    }
  }
}
