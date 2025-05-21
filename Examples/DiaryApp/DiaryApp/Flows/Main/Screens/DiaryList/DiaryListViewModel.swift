import Foundation
import Bindify
import SwiftUI

/// View model for the diary list screen
final class DiaryListViewModel: BindifyViewModel<DiaryContext, DiaryListViewModel.State, DiaryListViewModel.Action> {
  /// Actions that can be performed on the diary list
  enum Action: Equatable {
    case selectEntry(DiaryEntry)
    case clearSelection
    case startAddingNew
    case finishAddingNew
    case removeEntry(at: Int)
    case removeEntryById(UUID)
    case refresh
  }

  /// State for the diary list screen
  struct State: BindifyViewState {
    /// Collection of diary entries to display
    var entries: [DiaryEntry] = []
    /// Currently selected entry for navigation
    var selectedEntryId: UUID?
    /// Whether we're adding a new entry
    var isAddingNew: Bool = false
    /// Local UI state
    var isRefreshing: Bool = false

    func entry(at index: Int) -> DiaryEntry {
      entries[index]
    }
  }

  /// Creates a new diary list view model
  /// - Parameter context: The diary context to use
  override init(_ context: DiaryContext) {
    super.init(context)
  }

  /// Transforms the store state into the view state
  /// - Parameters:
  ///   - storeState: Current store state
  ///   - newState: The view state to be modified
  override func scopeStateOnStoreChange(
    _ storeState: DiaryStoreState,
    _ newState: inout State
  ) {
    newState.entries = storeState.entries.sorted { $0.createdAt > $1.createdAt }
    newState.isAddingNew = storeState.entrySelectionMode == .addingNew
    if case let .selecting(selectedEntry) = storeState.entrySelectionMode {
      newState.selectedEntryId = selectedEntry.id
    } else {
      newState.selectedEntryId = nil
    }
  }

  /// Handles both local and store state changes
  override func scopeStateOnAction(
    _ action: Action,
    _ newState: inout State
  ) -> ((inout DiaryStoreState) -> Void)? {
    switch action {
    case .selectEntry(let entry):
      return { state in
        state.entrySelectionMode = .selecting(entry)
      }

    case .clearSelection:
      return { state in
        state.entrySelectionMode = .no
      }

    case .startAddingNew:
      return { state in
        state.entrySelectionMode = .addingNew
      }

    case .finishAddingNew:
      newState.isAddingNew = false

    case .removeEntry(let index):
      let entry = newState.entry(at: index)
      return { state in
        state.entries.removeAll { $0.id == entry.id }
      }

    case .removeEntryById(let id):
      return { state in
        state.entries.removeAll { $0.id == id }
      }

    case .refresh:
      newState.isRefreshing = true
    }

    return nil
  }
}

