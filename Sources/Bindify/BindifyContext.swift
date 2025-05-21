//
//  BindifyContext.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

import Foundation

/// Context that provides access to the global store
///
/// The context serves as a dependency injection container for the store,
/// allowing views and view models to access the single source of truth.
/// In the unidirectional data flow pattern, all state changes must go through the store.
public protocol BindifyContext {
  /// The type of store state used by this context
  associatedtype StoreState: BindifyStoreState

  /// The store instance that manages the global application state
  var store: BindifyStore<StoreState> { get }
}
