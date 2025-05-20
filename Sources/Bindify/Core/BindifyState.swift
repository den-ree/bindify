//
//  BindifyState.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

/// Base protocol for all state types in the Bindify framework
/// 
/// All states must be value types (Equatable) and thread-safe (Sendable)
public protocol BindifyState: Equatable & Sendable {}

/// Represents the global application state that serves as the single source of truth
/// 
/// This state should contain only data that needs to be shared across multiple views
/// and represents the core data model of your application.
public protocol BindifyStoreState: BindifyState {}

/// Represents the UI-specific state derived from the global store state
/// 
/// This state is optimized for view rendering and contains derived/computed properties.
/// In the unidirectional data flow pattern, this state should never be directly mutated
/// but rather always derived from the store state.
public protocol BindifyLocalState: BindifyState {
  /// Default initializer for creating an empty state
  init()
}

/// Represents a state change event with metadata about the change
public struct BindifyStateChange<State: BindifyState>: Equatable, Sendable {
  /// Indicates what triggered the state change
  public enum Trigger: Equatable, Sendable {
    /// Initial connection to the store
    case storeConnection
    /// An update from the store propagated to the view
    case storeUpdate
    /// A forced refresh update within the view model
    case refreshUpdate
  }

  /// The event that triggered this state change
  public let trigger: Trigger
  /// The state before the change
  public let oldState: State
  /// The state after the change
  public let newState: State

  /// Whether this is the initial state (first load)
  public var isInitial: Bool { trigger == .storeConnection }

  /// Whether the state actually changed values
  var hasChanged: Bool { oldState != newState }
}
