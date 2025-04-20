//
//  BindifyStore.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

import Combine

/// An actor that manages a global state store with thread-safe access
///
/// `BindifyStateStore` provides a centralized, thread-safe way to manage application state
/// and handle event communication between different parts of the application.
public actor BindifyStore<State: BindifyGlobalState> {
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
  /// - Parameter block: A closure that modifies the current state
  func update(state block: (inout State) -> Void) {
    let oldState = state
    block(&state)

    if oldState != state {
      changesSubject.send((old: oldState, new: state))
    }
  }
}
