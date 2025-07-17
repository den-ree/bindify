import Foundation
import Bindify
import SwiftUI

/// View model for the diary list screen
final class DiaryListViewModel: BindifyViewModel<DiaryContext, DiaryListViewModel.State> {
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

    init() {}
  }

  /// Creates a new diary list view model
  /// - Parameter context: The diary context to use
  override init(_ context: DiaryContext) {
    super.init(context)
  }

  /// Transforms the store state into the view state
  /// - Parameter storeState: Current store state
  override func scopeStateOnStoreChange(
    _ storeState: DiaryStoreState
  ) async {
    updateState { state in
      state.entries = storeState.entries.sorted { $0.createdAt > $1.createdAt }
      state.isAddingNew = storeState.entrySelectionMode == .addingNew
      if case let .selecting(selectedEntry) = storeState.entrySelectionMode {
        state.selectedEntryId = selectedEntry.id
      } else {
        state.selectedEntryId = nil
      }
    }
  }

  // MARK: - Actions

  func selectEntry(_ entry: DiaryEntry) {
    updateStore { _, storeState in
      storeState.entrySelectionMode = .selecting(entry)
    }
  }

  func clearSelection() {
    updateStore { _, storeState in
      storeState.entrySelectionMode = .no
    }
  }

  func startAddingNew() {
    updateStore { _, storeState in
      storeState.entrySelectionMode = .addingNew
    }
  }

  func finishAddingNew() {
    updateState { state in
      state.isAddingNew = false
    }
  }

  func removeEntry(at index: Int) {
    let entry = state.entry(at: index)
    updateStore { _, storeState in
      storeState.entries.removeAll { $0.id == entry.id }
    }
  }

  func removeEntryById(_ id: UUID) {
    updateStore { _, storeState in
      storeState.entries.removeAll { $0.id == id }
    }
  }

  func refresh() {
    updateState { state in
      state.isRefreshing = true
    }
  }
}

