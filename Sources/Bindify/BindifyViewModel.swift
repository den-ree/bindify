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
  associatedtype Action: Equatable
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
/// - ``onStateEvent(_:_:)``
///
/// ### Related Types
///
/// - ``BindifyContext``
/// - ``BindifyViewState``
/// - ``BindifyStateChange``
open class BindifyViewModel<StoreContext: BindifyContext, ViewState: BindifyViewState, Action: Equatable>: BindifiableViewModel {
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
          self.updateState(newState, trigger: old == nil ? .storeConnection : .storeUpdate)
        }
      }.store(in: &cancellables)
    }
  }

  deinit {
    cancellables.forEach { $0.cancel() }
    cancellables.removeAll()
  }

  @MainActor func send(_ action: Action) {
    onAction(action)
  }

  /// Scopes the action into state changes
  ///
  /// This method handles both local view state changes and store state changes.
  /// It should be pure and deterministic - the same action and state should always produce the same changes.
  ///
  /// ## Overview
  ///
  /// This method is called for every action and should:
  /// - Update the view state based on the action
  /// - Return a store update closure if the action requires store changes
  ///
  /// ## Usage
  ///
  /// ```swift
  /// override func scopeStateOnAction(
  ///     _ action: UserProfileAction,
  ///     _ newState: inout UserProfileViewState
  /// ) -> ((inout AppContext.StoreState) -> Void)? {
  ///     switch action {
  ///     case .updateName(let name):
  ///         newState.name = name
  ///         return nil
  ///     case .save:
  ///         return { state in
  ///             state.userProfile.name = newState.name
  ///         }
  ///     }
  /// }
  /// ```
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

  /// Called when a state event occurs
  ///
  /// This method is called for all state-related events, including:
  /// - State changes (will/did)
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
  /// override func onStateEvent(_ event: BindifyStateEvent<Action>, _ change: BindifyStateChange<ViewState>) {
  ///     switch event {
  ///     case .willChange:
  ///         // Handle state will change
  ///     case .didChange:
  ///         // Handle state did change
  ///     case .onAction(let action):
  ///         // Handle action processing
  ///     }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - event: The type of state event that occurred
  ///   - change: The state change that occurred
  @MainActor
  open func onStateEvent(_ event: BindifyStateEvent<Action>, _ change: BindifyStateChange<ViewState>) {}

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
  func onAction(_ action: Action) {
    var newState = viewState
    let storeUpdate = scopeStateOnAction(action, &newState)
    let change = updateState(newState, trigger: .actionUpdate)

    if let update = storeUpdate {
      Task {
        await context.store.update(state: update)
      }
    }

    onStateEvent(.onAction(action), change)
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
  @MainActor 
  @discardableResult func updateState(_ newState: ViewState, trigger: BindifyStateChange<ViewState>.Trigger) -> BindifyStateChange<ViewState> {
    let change = BindifyStateChange(trigger: trigger, oldState: viewState, newState: newState)

    guard change.hasChanged || change.isInitial else { return change }

    onStateEvent(.willChange, change)
    viewState = change.newState
    onStateEvent(.didChange, change)

    return change
  }
}

