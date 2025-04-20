//
//  BindifyContext.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

import Foundation

/// Context to keep store

public protocol BindifyContext {
  associatedtype StoreState: BindifyGlobalState

  var store: BindifyStore<StoreState> { get }
}
