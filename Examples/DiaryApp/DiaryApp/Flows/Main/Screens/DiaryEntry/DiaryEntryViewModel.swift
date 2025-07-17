import Foundation
import Bindify
import SwiftUI

final class DiaryEntryViewModel: BindifyViewModel<DiaryContext, DiaryEntryViewModel.State> {
  enum SavingStatus: Equatable {
    case no
    case saving
    case saved
  }

  /// State for the add diary entry screen
  struct State: BindifyViewState {
    var title: String = ""
    var content: String = ""
    var savingStatus: SavingStatus = .no
    var isEditing: Bool = false
    var entryTitle: String = ""
    var shouldDismiss: Bool = false

    var isSavingDisabled: Bool {
      title.isEmpty || savingStatus == .saving
    }

    var isSaved: Bool {
      savingStatus == .saved
    }

    init() {}
  }

  /// Creates a new add diary entry view model
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
      if state.savingStatus == .saving { return }

      switch storeState.entrySelectionMode {
      case .addingNew:
        state.entryTitle = "New Entry"
        state.shouldDismiss = false
      case let .selecting(entry):
        state.title = entry.title
        state.content = entry.content
        state.entryTitle = entry.title
        state.shouldDismiss = false
      case .no:
        state.entryTitle = ""
        state.title = ""
        state.content = ""
        state.shouldDismiss = true
      }
    }
  }

  // MARK: - Actions

  @MainActor func updateTitle(_ title: String) {
    updateState { state in
      state.title = title
    }
  }

  @MainActor func updateContent(_ content: String) {
    updateState { state in
      state.content = content
    }
  }

  @MainActor func startEditing() {
    updateState { state in
      state.isEditing = true
    }
  }

  @MainActor
  func finishEditing(save: Bool) {
    guard save else {
        updateState { state in
          state.isEditing = false
        }.sideEffect { [weak self] _ in
          self?.updateStore {
            $0.entrySelectionMode = .no
          }
        }
      return
    }

    updateState { state in
      state.savingStatus = .saving

      guard !state.title.isEmpty else {
        return
      }
    }.sideEffect { [weak self] change in
      guard let self, change.hasChanged else { return }
      let state = change.newState

      let newEntry = DiaryEntry(
        id: .init(),
        title: state.title,
        content: state.content,
        createdAt: .now
      )

      self.updateStore { storeState in
        switch storeState.entrySelectionMode {
        case .addingNew:
          storeState.entries.append(newEntry)
        case let .selecting(existingEntry):
          let updatedEntry = existingEntry.new(title: newEntry.title, content: newEntry.content)
          storeState.entries = storeState.entries.map { $0.id == existingEntry.id ? updatedEntry : $0 }
        case .no:
          break
        }
      }
      try? await Task.sleep(for: .seconds(2))
      markAsSaved()
    }
  }

  @MainActor
  func markAsSaved() {
    updateState { state in
      state.savingStatus = .saved
      state.isEditing = false
    }.sideEffect {  [weak self] change in
      self?.updateStore { storeState in
        storeState.entrySelectionMode = .no
      }
    }
  }
}


