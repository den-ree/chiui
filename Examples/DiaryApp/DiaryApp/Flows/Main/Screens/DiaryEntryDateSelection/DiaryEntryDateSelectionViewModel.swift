import Foundation
import Chiui

final class DiaryEntryDateSelectionViewModel: ContextViewModel<DiaryContext, DiaryEntryDateSelectionViewModel.State> {
  struct State: ContextualViewState {
    var selectedDate: Date = .now
  }

  nonisolated override func didStoreUpdate(_ storeState: DiaryStoreState) async {
    await updateState { state in
      if let draftDate = storeState.entryDraftDate {
        state.selectedDate = draftDate
        return
      }

      switch storeState.entrySelectionMode {
      case let .selecting(entry):
        state.selectedDate = entry.createdAt
      case .addingNew, .no:
        state.selectedDate = .now
      }
    }
  }

  func updateSelectedDate(_ date: Date) {
    Task {
      await updateState { state in
        state.selectedDate = date
      }.then { [weak self] change in
        guard let self, change.hasChanged else { return }

        self.updateStore { storeState in
          storeState.entryDraftDate = change.newState.selectedDate
        }
      }
    }
  }

  func confirmSelection() {
    updateStore { storeState in
      storeState.isSelectingEntryDate = false
    }
  }

  func cancelSelection() {
    updateStore { storeState in
      storeState.isSelectingEntryDate = false
    }
  }
}
