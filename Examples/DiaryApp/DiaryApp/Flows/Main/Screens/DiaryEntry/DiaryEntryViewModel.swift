import Foundation
import Chiui
import SwiftUI

final class DiaryEntryViewModel: ContextViewModel<DiaryContext, DiaryEntryViewModel.State> {
  enum SavingStatus: Equatable {
    case no
    case saving
    case saved
  }

  /// State for the add diary entry screen
  struct State: ContextualViewState {
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
  nonisolated override func didStoreUpdate(
    _ storeState: DiaryStoreState
  ) async {
    await updateState { state in
      if state.savingStatus == .saving { return }

      switch storeState.entrySelectionMode {
      case .addingNew:
        state.entryTitle = "New Entry"
      case let .selecting(entry):
        state.title = entry.title
        state.content = entry.content
        state.entryTitle = entry.title
      case .no:
        break
      }
    }
  }

  // MARK: - Actions

  func updateTitle(_ title: String) {
    updateState { state in
      state.title = title
    }
  }

  func updateContent(_ content: String) {
    updateState { state in
      state.content = content
    }
  }

  func startEditing() {
    updateState { state in
      state.isEditing = true
    }
  }

  func finishEditing(save: Bool) async {
    guard save else {
        await updateState { state in
          state.isEditing = false
        }.then { [weak self] _ in
          self?.updateStore {
            $0.entrySelectionMode = .no
          }
        }
      return
    }

    await updateState { state in
      state.savingStatus = .saving

      guard !state.title.isEmpty else {
        return
      }
    }.then { [weak self] change in
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
      // Simulate loading work via a non-Sendable client.
      await self.context.loadingClient.simulateLoadingWork()
      await markAsSaved()
    }
  }

  func markAsSaved() async {
    // Example of waiting
    await updateState { state in
      state.savingStatus = .saved
      state.isEditing = false
    }.then {  [weak self] _ in
      self?.updateStore { storeState in
        storeState.entrySelectionMode = .no
      }
    }
  }
}
