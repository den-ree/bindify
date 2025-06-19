//
//  BindifyViewModel.swift
//  Bindify
//
//  Created by Den Ree on 04/04/2025.
//

@preconcurrency import Combine

/// A protocol that defines the basic requirements for a view model in the Bindify framework.
///
/// `BindifiableViewModel` serves as the foundation for view models, requiring them to:
/// - Be observable objects for SwiftUI integration
/// - Define their store context type
/// - Define their view state type
/// - Define their action type
///
/// ## Overview
///
/// This protocol is the base requirement for all view models in the Bindify framework.
/// It ensures that view models can properly integrate with the store and handle state updates.
public protocol BindifiableViewModel: ObservableObject {
  /// The type of context that provides access to the store.
  associatedtype StoreContext: BindifyContext

  /// The type of state used by this view model.
  associatedtype ViewState: BindifyViewState

  /// The type of actions that can be processed by this view model.
  associatedtype Action: BindifyAction
}

/// A base view model class that integrates with a store and manages state.
///
/// `BindifyViewModel` provides core functionality for:
/// - Unidirectional data flow from store state to view state
/// - Store state updates through actions
/// - Reactive updates when store state changes
/// - Lifecycle management of subscriptions
///
/// ## Overview
///
/// This class implements the core state management logic for views in the Bindify framework.
/// It handles the bidirectional flow of data between the store and the view, ensuring that:
/// - Store updates are properly reflected in the view state
/// - Actions can update both local state and store state
/// - State changes are properly tracked and lifecycle hooks are called
///
/// ## Usage
///
/// ```swift
/// final class UserProfileViewModel: BindifyViewModel<AppContext, UserProfileViewState, UserProfileAction> {
///     override func scopeStateOnAction(
///         _ action: UserProfileAction,
///         _ newState: inout UserProfileViewState
///     ) -> ((inout AppContext.StoreState) -> Void)? {
///         switch action {
///         case .updateName(let name):
///             newState.name = name
///             return nil
///         case .save:
///             return { state in
///                 state.userProfile.name = newState.name
///             }
///         }
///     }
///
///     override func scopeStateOnStoreChange(
///         _ storeState: AppContext.StoreState,
///         _ newState: inout UserProfileViewState
///     ) {
///         newState.name = storeState.userProfile.name
///     }
///
///     override func onStateEvent(_ event: BindifyStateEvent<UserProfileAction, UserProfileViewState>) {
///         switch event.trigger {
///         case .initial:
///             // Handle initial state
///         case .store:
///             // Handle store update
///         case .action(let action):
///             // Handle action side effects
///             switch action {
///             case .updateName:
///                 // Handle name update side effects
///             case .save:
///                 // Handle save side effects
///             }
///         }
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Essentials
///
/// - ``StoreContext``
/// - ``ViewState``
/// - ``Action``
/// - ``context``
/// - ``viewState``
///
/// ### State Management
///
/// - ``scopeStateOnAction(_:_:)``
/// - ``scopeStateOnStoreChange(_:_:)``
/// - ``onAction(_:)``
/// - ``onStateEvent(_:)``
///
/// ### Related Types
///
/// - ``BindifyContext``
/// - ``BindifyViewState``
/// - ``BindifyStateChange``
/// - ``BindifyStateEvent``
open class BindifyViewModel<StoreContext: BindifyContext, ViewState: BindifyViewState, Action: BindifyAction>: BindifiableViewModel {
  /// Set of cancellables to manage subscriptions
  private var cancellables = Set<AnyCancellable>()

  /// The store context used by this view model
  public let context: StoreContext

  /// The current read-only state derived from the store state, specifically scoped for the view
  @Published fileprivate(set) var viewState: ViewState

  /// Creates a new view model instance with the given store context
  /// - Parameter context: The store context to use for state management
  @MainActor public init(_ context: StoreContext) {
    self.context = context
    self.viewState = .init()

    let store = context.store

    Task { @MainActor in
      await store.subscribe { [weak self] old, new in
        guard let self = self else { return }
        var newState = self.viewState
        self.scopeStateOnStoreChange(new, &newState)
        Task { @MainActor in

          let change = BindifyStateChange(oldState: self.viewState, newState: newState)

          if change.hasChanged {
            self.viewState = change.newState
          }

          self.onStateEvent(.init(store: store, trigger: old == nil ? .initial : .store, change: change))
        }
      }.store(in: &cancellables)
    }
  }

  deinit {
    cancellables.forEach { $0.cancel() }
    cancellables.removeAll()
  }

  /// Scopes the store state into the local view state
  ///
  /// This is the core mapping function that defines how the view state is derived from the store state.
  /// It should be pure and deterministic - the same store state should always produce the same view state.
  ///
  /// ## Overview
  ///
  /// This method is called whenever the store state changes and should:
  /// - Map relevant store state to view state
  /// - Handle any derived state calculations
  /// - Maintain UI-specific state
  ///
  /// ## Usage
  ///
  /// ```swift
  /// override func scopeStateOnStoreChange(
  ///     _ storeState: AppContext.StoreState,
  ///     _ newState: inout UserProfileViewState
  /// ) {
  ///     newState.name = storeState.userProfile.name
  ///     newState.isSavingDisabled = storeState.userProfile.name.isEmpty
  /// }
  /// ```
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

  /// Scopes the action into state changes
  ///
  /// This method handles local view state changes based on actions.
  /// It should be pure and deterministic - the same action and state should always produce the same changes.
  ///
  /// ## Overview
  ///
  /// This method is called for every action and should:
  /// - Update the view state based on the action
  /// - Handle any derived state calculations
  /// - Maintain UI-specific state
  ///
  /// For store updates, use the `updateStore` method within `onStateEvent`.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// override func scopeStateOnAction(
  ///     _ action: UserProfileAction,
  ///     _ newState: inout UserProfileViewState
  /// ) {
  ///     switch action {
  ///     case .updateName(let name):
  ///         newState.name = name
  ///     case .toggleEditing:
  ///         newState.isEditing.toggle()
  ///     }
  /// }
  ///
  /// override func onStateEvent(_ event: BindifyStateEvent<UserProfileAction, UserProfileViewState>) {
  ///     switch event.trigger {
  ///     case .action(let action):
  ///         switch action {
  ///         case .save:
  ///             updateStore { state in
  ///                 state.userProfile.name = viewState.name
  ///             }
  ///         default:
  ///             break
  ///         }
  ///     default:
  ///         break
  ///     }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - action: The action being processed
  ///   - newState: The current view state to be modified
  open func scopeStateOnAction(
    _ action: Action,
    _ newState: inout ViewState
  ) {
    // Default implementation does nothing
  }

  /// Called when a state event occurs
  ///
  /// This method is called for all state-related events, including:
  /// - Initial state connection
  /// - Store updates
  /// - Action processing
  ///
  /// ## Overview
  ///
  /// This method serves as a single entry point for all state-related events,
  /// making it easier to handle different types of events in a unified way.
  ///
  /// ## Usage
  ///
  /// ```swift
  /// override func onStateEvent(_ event: BindifyStateEvent<Action, ViewState>) {
  ///     switch event.trigger {
  ///     case .initial:
  ///         // Handle initial state
  ///     case .store:
  ///         // Handle store update
  ///     case .action(let action):
  ///         // Handle action side effects
  ///         switch action {
  ///         case .updateName:
  ///             // Handle name update side effects
  ///         case .save:
  ///             // Handle save side effects
  ///         }
  ///     }
  /// }
  /// ```
  ///
  /// - Parameter event: The state event that occurred
  @MainActor
  open func onStateEvent(_ event: BindifyStateEvent<Action, ViewState, StoreContext.StoreState>) {}

  /// Updates the global store's state using a mutation block
  ///
  /// - Parameter block: A closure that modifies the store's state
  @MainActor
  public func updateStore(_ block: @escaping (inout StoreContext.StoreState) -> Void) {
    Task { @MainActor in
      await context.store.update(state: block)
    }
  }

  /// Sends an action to the view model
  ///
  /// This method is used to trigger actions within the view model.
  /// It updates the view state and triggers the appropriate state event.
  ///
  /// - Parameter action: The action to send
  @MainActor
  public func send(_ action: Action) {
    onAction(action)
  }

  /// Subscribes to a cancellable and stores it for lifecycle management
  ///
  /// This method ensures that subscriptions are properly managed and cleaned up
  /// when the view model is deallocated.
  ///
  /// - Parameter cancelable: The cancellable to store
  public func subscribeOn(_ cancelable: AnyCancellable) {
    cancelable.store(in: &cancellables)
  }

  /// The main entry point for handling actions
  ///
  /// This method processes actions and updates state accordingly.
  /// It first updates the view state based on the action, then optionally updates the store.
  ///
  /// ## Overview
  ///
  /// The action handling process follows these steps:
  /// 1. Update the view state based on the action
  /// 2. If the action requires store updates, update the store state
  /// 3. Notify observers of state changes
  ///
  /// ## Usage
  ///
  /// ```swift
  /// viewModel.onAction(.updateName("John"))
  /// ```
  ///
  /// - Parameter action: The action to process
  @MainActor
  private func onAction(_ action: Action) {
    var oldState = viewState
    var newState = viewState
    scopeStateOnAction(action, &newState)

    let change = BindifyStateChange(oldState: oldState, newState: newState)

    if change.hasChanged {
      viewState = change.newState
    }

    onStateEvent(.init(store: context.store, trigger: .action(action), change: change))
  }
}
