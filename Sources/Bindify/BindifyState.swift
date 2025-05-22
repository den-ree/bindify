//
//  BindifyState.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

/// A protocol that defines the base requirements for all state types in the Bindify framework.
///
/// All states in Bindify must conform to this protocol, which ensures they are:
/// - Value types that can be compared for equality
/// - Thread-safe for concurrent access
///
/// ## Overview
///
/// The `BindifyState` protocol serves as the foundation for all state management in Bindify.
/// It enforces immutability and thread safety, which are crucial for predictable state management
/// in a unidirectional data flow architecture.
///
/// ## Usage
///
/// ```swift
/// struct UserState: BindifyState {
///     let id: String
///     let name: String
///     let isActive: Bool
/// }
/// ```
///
/// ## Topics
///
/// ### Related Types
///
/// - ``BindifyStoreState``
/// - ``BindifyViewState``
public protocol BindifyState: Equatable & Sendable {}

/// A protocol that defines the state for a store in the Bindify framework.
///
/// The `BindifyStoreState` represents the source of truth for your application or feature.
/// It should contain only the essential data that needs to be shared and persisted.
///
/// ## Overview
///
/// Store states should be:
/// - Minimal and focused on core data
/// - Serializable for persistence
/// - Thread-safe for concurrent access
///
/// ## Usage
///
/// ```swift
/// struct AppStoreState: BindifyStoreState {
///     var user: User?
///     var settings: Settings
///     var isAuthenticated: Bool
/// }
/// ```
///
/// ## Topics
///
/// ### Related Types
///
/// - ``BindifyState``
/// - ``BindifyViewState``
public protocol BindifyStoreState: BindifyState {}

/// A protocol that defines the state for a view in the Bindify framework.
///
/// The `BindifyViewState` represents the UI-specific state that can be updated in two ways:
/// 1. Derived from store state (for shared data)
/// 2. Updated through actions (for local UI state)
///
/// ## Overview
///
/// View states should:
/// - Contain both derived and local UI state
/// - Be updated through actions in a unidirectional flow
/// - Never be directly mutated outside of the view model
/// - Have a default empty initializer
///
/// ## Usage
///
/// ```swift
/// struct UserViewState: BindifyViewState {
///     // Derived from store state
///     var displayName: String
///     var isOnline: Bool
///     
///     // Local UI state
///     var isEditing: Bool
///     var selectedTab: Int
///     var lastSeen: String
///     
///     init() {
///         self.displayName = ""
///         self.isOnline = false
///         self.isEditing = false
///         self.selectedTab = 0
///         self.lastSeen = ""
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Essentials
///
/// - ``init()``
///
/// ### Related Types
///
/// - ``BindifyState``
/// - ``BindifyStoreState``
public protocol BindifyViewState: BindifyState, Sendable {
    /// Creates an empty state instance.
    ///
    /// This initializer is required to support state initialization before
    /// any data is available from the store.
    init()
}

/// A structure that represents a state change event with metadata.
///
/// `BindifyStateChange` tracks the lifecycle of state changes, including:
/// - What triggered the change
/// - The previous state
/// - The new state
/// - Whether it's an initial state
/// - Whether the state actually changed
///
/// ## Overview
///
/// State changes can be triggered by:
/// - Initial store connection
/// - Store updates
/// - Local actions
///
/// ## Usage
///
/// ```swift
/// let change = BindifyStateChange(
///     trigger: .actionUpdate,
///     oldState: previousState,
///     newState: currentState
/// )
///
/// if change.hasChanged {
///     // Handle state update
/// }
/// ```
///
/// ## Topics
///
/// ### Essentials
///
/// - ``Trigger``
/// - ``trigger``
/// - ``oldState``
/// - ``newState``
/// - ``isInitial``
/// - ``hasChanged``
public struct BindifyStateChange<State: BindifyState>: Equatable, Sendable {
    /// The type of event that triggered a state change.
    ///
    /// State changes can be triggered by:
    /// - Initial connection to the store
    /// - Updates from the store
    /// - Local actions within the view model
    public enum Trigger: Equatable, Sendable {
        /// The initial connection to the store when a view model is created.
        case storeConnection
        /// An update propagated from the store to the view.
        case storeUpdate
        /// A local update triggered by an action within the view model.
        case actionUpdate
    }

    /// The event that triggered this state change.
    public let trigger: Trigger

    /// The state before the change occurred.
    public let oldState: State

    /// The state after the change occurred.
    public let newState: State

    /// Whether this is the initial state (first load).
    public var isInitial: Bool { trigger == .storeConnection }

    /// Whether the state actually changed values.
    var hasChanged: Bool { oldState != newState }
}
