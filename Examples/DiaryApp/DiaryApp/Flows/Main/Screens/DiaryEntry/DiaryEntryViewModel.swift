import Foundation
import Bindify
import SwiftUI

final class DiaryEntryViewModel: BindifyViewModel<DiaryContext, DiaryEntryViewModel.State, DiaryEntryViewModel.Action> {
  enum Action: Equatable {
    case updateTitle(String)
    case updateContent(String)
    case startEditing
    case finishEditing(save: Bool)
    case markAsSaved
  }

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
  /// - Parameters:
  ///   - storeState: Current store state
  ///   - newState: The view state to be modified
  override func scopeStateOnStoreChange(
    _ storeState: DiaryStoreState,
    _ newState: inout State
  ) {
    if newState.savingStatus == .saving { return }

    switch storeState.entrySelectionMode {
    case .addingNew:
      newState.entryTitle = "New Entry"
      newState.shouldDismiss = false
    case let .selecting(entry):
      newState.title = entry.title
      newState.content = entry.content
      newState.entryTitle = entry.title
      newState.shouldDismiss = false
    case .no:
      newState.entryTitle = ""
      newState.title = ""
      newState.content = ""
      newState.shouldDismiss = true
    }
  }

  /// Handles both local and store state changes
  override func scopeStateOnAction(
    _ action: Action,
    _ newState: inout State
  ) -> ((inout DiaryStoreState) -> Void)? {
    switch action {
    case .updateTitle(let title):
      newState.title = title

    case .updateContent(let content):
      newState.content = content

    case .startEditing:
      newState.isEditing = true

    case .finishEditing(let save):
      guard save else {
        newState.isEditing = false
        return { state in
          state.entrySelectionMode = .no
        }
      }

      newState.savingStatus = .saving

      guard !newState.title.isEmpty else {
        return nil
      }

      let newEntry = DiaryEntry(
        id: .init(),
        title: newState.title,
        content: newState.content,
        createdAt: .now
      )

      return { state in
        switch state.entrySelectionMode {
        case .addingNew:
          state.entries.append(newEntry)
        case let .selecting(existingEntry):
          let updatedEntry = existingEntry.new(title: newEntry.title, content: newEntry.content)
          state.entries = state.entries.map { $0.id == existingEntry.id ? updatedEntry : $0 }
        case .no:
          break
        }
      }

    case .markAsSaved:
      newState.savingStatus = .saved
      newState.isEditing = false
      return { state in
        state.entrySelectionMode = .no
      }
    }

    return nil
  }

  override func onStateDidChange(_ change: BindifyStateChange<State>) async {
    if change.isStartedSaving {
      try? await Task.sleep(for: .seconds(2))
      onAction(.markAsSaved)
    }
  }
}

extension BindifyStateChange<DiaryEntryViewModel.State> {
  var isStartedSaving: Bool {
    newState.savingStatus == .saving && oldState.savingStatus != newState.savingStatus && trigger == .actionUpdate
  }
}


