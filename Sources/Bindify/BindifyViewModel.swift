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
}

/// A base view model class that integrates with a store and manages state.
///
/// `BindifyViewModel` provides core functionality for:
/// - Unidirectional data flow from store state to view state
/// - Reactive updates when store state changes
/// - Lifecycle management of subscriptions
/// - Fluent state update API with chaining
///
/// ## Overview
///
/// This class implements the core state management logic for views in the Bindify framework.
/// It handles the flow of data between the store and the view, ensuring that:
/// - Store updates are properly reflected in the view state
/// - State changes are properly tracked and managed
/// - Clean separation between local and global state
///
/// ## Usage
///
/// ```swift
/// final class UserProfileViewModel: BindifyViewModel<AppContext, UserProfileViewState> {
///     override func scopeStateOnStoreChange(_ storeState: AppContext.StoreState) async {
///         updateState { state in
///             state.name = storeState.userProfile.name
///             state.isSavingDisabled = storeState.userProfile.name.isEmpty
///         }
///     }
///     
///     func updateName(_ name: String) {
///         updateState { state in
///             state.name = name
///         }.updateStore { change, storeState in
///             storeState.userProfile.name = change.newState.name
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
/// - ``context``
/// - ``viewState``
///
/// ### State Management
///
/// - ``scopeStateOnStoreChange(_:)``
/// - ``updateState(_:)``
/// - ``updateStore(_:)``
///
/// ### Related Types
///
/// - ``BindifyContext``
/// - ``BindifyViewState``
/// - ``BindifyStateChange``
/// - ``BindifyStateSideEffect``
open class BindifyViewModel<StoreContext: BindifyContext, ViewState: BindifyViewState>: BindifiableViewModel {
  /// Set of cancellables to manage subscriptions
  private var cancellables = Set<AnyCancellable>()

  private var hasInitialState: Bool = true

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

    Task {
      await store.subscribe { [weak self] old, new in
        guard let self = self else { return }
        
        Task {
          await self.scopeStateOnStoreChange(new)
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
  /// - Map relevant store state to view state using `updateState`
  /// - Handle any derived state calculations
  /// - Maintain UI-specific state
  ///
  /// ## Usage
  ///
  /// ```swift
  /// override func scopeStateOnStoreChange(_ storeState: AppContext.StoreState) async {
  ///     updateState { state in
  ///         state.name = storeState.userProfile.name
  ///         state.isSavingDisabled = storeState.userProfile.name.isEmpty
  ///     }
  /// }
  /// ```
  ///
  /// - Parameter storeState: The current store state
  open func scopeStateOnStoreChange(
    _ storeState: StoreContext.StoreState
  ) async {
    // Default implementation does nothing
  }

  /// Updates the global store's state using a mutation block
  ///
  /// - Parameter block: A closure that modifies the store's state
  @MainActor
  public func updateStore(_ block: @escaping (inout StoreContext.StoreState) -> Void) {
    Task { @MainActor in
      await context.store.update(state: block)
    }
  }

  @MainActor
  @discardableResult
  public func updateState(_ block: @escaping @MainActor (inout ViewState) -> Void) -> BindifyStateSideEffect<ViewState> {
    let oldState = viewState
    var newState = viewState
    block(&newState)

    let change = BindifyStateChange(oldState: oldState, newState: newState, isInitial: hasInitialState)

    if change.hasChanged {
      viewState = change.newState
      hasInitialState = false
    }

    return .init(change: change)
  }

  @MainActor
  public func sideEffect(_ block: @escaping @MainActor (ViewState) async -> Void) async -> Void {
    await block(viewState)
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
}
