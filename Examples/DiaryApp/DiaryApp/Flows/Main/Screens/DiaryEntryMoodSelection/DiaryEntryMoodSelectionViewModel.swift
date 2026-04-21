import Foundation
import Chiui

final class DiaryEntryMoodSelectionViewModel: ContextViewModel<DiaryContext, DiaryEntryMoodSelectionViewModel.State> {
  struct State: ContextualViewState {
    var selectedMood: DiaryEntryMood = .okay
  }

  nonisolated override func didStoreUpdate(_ storeState: DiaryStoreState) async {
    await updateState { state in
      if let draftMood = storeState.entryDraftMood {
        state.selectedMood = draftMood
        return
      }

      switch storeState.entrySelectionMode {
      case let .selecting(entry):
        state.selectedMood = entry.mood
      case .addingNew, .no:
        state.selectedMood = .okay
      }
    }
  }

  func updateSelectedMood(_ mood: DiaryEntryMood) {
    Task {
      await updateState { state in
        state.selectedMood = mood
      }.then { [weak self] change in
        guard let self, change.hasChanged else { return }

        self.updateStore { storeState in
          storeState.entryDraftMood = change.newState.selectedMood
        }
      }
    }
  }

  func confirmSelection() {
    updateStore { storeState in
      storeState.isSelectingEntryMood = false
    }
  }

  func cancelSelection() {
    updateStore { storeState in
      storeState.isSelectingEntryMood = false
    }
  }
}
