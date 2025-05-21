import Foundation
import Bindify
import SwiftUI

final class DiaryEntryViewModel: BindifyViewModel<DiaryContext, DiaryEntryViewModel.State>, BindifyStatableViewModel {

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
  /// - Returns: New view state
  override func scopeStateOnStoreChange(_ storeState: DiaryStoreState) -> State {
    var nextState = viewState

    switch storeState.entrySelectionMode {
    case .addingNew:
      nextState.entryTitle = "New Entry"
    case let .selecting(entry):
      nextState.title = entry.title
      nextState.content = entry.content
      nextState.entryTitle = entry.title
    case .no:
      nextState.entryTitle = ""
      nextState.title = ""
      nextState.content = ""
    }

    return nextState
  }

  /// Updates the title of the new entry
  /// - Parameter title: New title
  @MainActor
  func updateTitle(_ title: String) {
    updateState { state in
      state.title = title
      state.isEditing = true
    }
  }

  /// Updates the content of the new entry
  /// - Parameter content: New content
  @MainActor
  func updateContent(_ content: String) {
    updateState { state in
      state.content = content
    }
  }

  /// Sets the editing state
  /// - Parameter isEditing: Whether the user is currently editing
  @MainActor
  func startEditing() {
    updateState { state in
      state.isEditing = true
    }
  }

  @MainActor
  func finishEditing(save: Bool) {
    updateState { state in
      state.savingStatus = .saving
    }

    guard !viewState.title.isEmpty else {
      return
    }

    let newEntry = DiaryEntry(id: .init(),
                           title: viewState.title,
                           content: viewState.content,
                           createdAt: .now)

    Task {
      try? await Task.sleep(for: .seconds(2))
      dispatchUpdate { state in
        switch state.entrySelectionMode {
          case .addingNew:
          state.entries.append(newEntry)
        case let .selecting(existingEntry):
          let updatedEntry = existingEntry.new(title: newEntry.title, content: newEntry.content)
          state.entries = state.entries.map { $0.id == existingEntry.id  ? updatedEntry : $0 }
        case .no: break
        }
        state.entrySelectionMode = .no
      }

      updateState { state in
        state.savingStatus = .saved
        state.isEditing = false
      }
    }
  }
}



