import Foundation
import Bindify

/// Context for managing diary state and actions
final class DiaryContext: BindifyContext {
  /// The store managing the diary state
  let store: BindifyStore<DiaryStoreState>

  /// Creates a new diary context
  /// - Parameter initialState: Initial state for the store
  init(initialState: DiaryStoreState = .init()) {
    self.store = BindifyStore(initialState)
  }
}
