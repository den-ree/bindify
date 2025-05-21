import Foundation
import Bindify
import SwiftUI

/// State for the diary list screen
struct DiaryListState: BindifyViewState {
  /// Collection of diary entries to display
  var entries: [DiaryEntry] = []
  /// Currently selected entry for navigation
  var selectedEntryId: UUID?
  /// Whether we're adding a new entry
  var isAddingNew: Bool = false

  func entry(at index: Int) -> DiaryEntry {
    entries[index]
  }
}

/// View model for the diary list screen
final class DiaryListViewModel: BindifyViewModel<DiaryContext, DiaryListState>, BindifyStatableViewModel {

  @MainActor func selectEntry(_ entry: DiaryEntry) {
    dispatchUpdate {
      $0.entrySelectionMode = .selecting(entry)
    }
  }

  @MainActor func clearSelection() {
    dispatchUpdate {
      $0.entrySelectionMode = .no
    }
  }

  @MainActor func startAddingNew() {
    dispatchUpdate {
      $0.entrySelectionMode = .addingNew
    }
  }

  @MainActor func finishAddingNew() {
    updateState { state in
      state.isAddingNew = false
    }
  }

  func removeEntry(at index: Int) {
    let entry = viewState.entry(at: index)
    removeEntry(id: entry.id)
  }

  /// Creates a new diary list view model
  /// - Parameter context: The diary context to use
  override init(_ context: DiaryContext) {
    super.init(context)
  }

  /// Transforms the store state into the view state
  /// - Parameter storeState: Current store state
  /// - Returns: New view state
  override func scopeStateOnStoreChange(_ storeState: DiaryStoreState) -> DiaryListState {
    var nextState = viewState
    nextState.entries = storeState.entries.sorted { $0.createdAt > $1.createdAt }
    nextState.isAddingNew = storeState.entrySelectionMode == .addingNew
    if case let .selecting(selectedEntry) = storeState.entrySelectionMode {
      nextState.selectedEntryId = selectedEntry.id
    } else {
      nextState.selectedEntryId = nil
    }
    return nextState
  }

  /// Removes a diary entry
  /// - Parameter id: ID of the entry to remove
  func removeEntry(id: UUID) {
    dispatchUpdate { state in
      state.entries.removeAll { $0.id == id }
    }
  }
}

