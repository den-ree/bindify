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
    await updateState { state in
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

  @MainActor
  func selectEntry(_ entry: DiaryEntry) {
    updateStore { storeState in
      storeState.entrySelectionMode = .selecting(entry)
    }
  }

  @MainActor
  func clearSelection() {
    updateStore { storeState in
      storeState.entrySelectionMode = .no
    }
  }

  @MainActor
  func startAddingNew() {
    updateStore { storeState in
      storeState.entrySelectionMode = .addingNew
    }
  }

  @MainActor
  func finishAddingNew() {
    updateState { state in
      state.isAddingNew = false
    }
  }

  @MainActor
  func removeEntry(at index: Int) {
    Task {
      await sideEffect { [weak self] state in
        let entry = state.entry(at: index)
        
        self?.updateStore { storeState in
          storeState.entries.removeAll { $0.id == entry.id }
        }
      }
    }
  }

  @MainActor
  func removeEntryById(_ id: UUID) {
    updateStore { storeState in
      storeState.entries.removeAll { $0.id == id }
    }
  }

  @MainActor
  func refresh() {
    updateState { state in
      state.isRefreshing = true
    }
  }
}

