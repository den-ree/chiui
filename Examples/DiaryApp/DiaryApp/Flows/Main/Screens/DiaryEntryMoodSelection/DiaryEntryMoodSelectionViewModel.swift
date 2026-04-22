import Foundation
import Chiui

final class DiaryEntryMoodSelectionViewModel: ContextViewModel<
  DiaryContext,
  DiaryEntryMoodSelectionViewModel.State,
  DiaryEntryMoodSelectionViewModel.Action,
  DiaryEntryMoodSelectionViewModel.Effect
> {
  struct State: ContextualViewState {
    var selectedMood: DiaryEntryMood = .okay
  }

  enum Action: Equatable, ContextualAction {
    case storeChanged(DiaryStoreState)
    case selectedMoodChanged(DiaryEntryMood)
    case confirmSelection
    case cancelSelection
  }

  enum Effect: Equatable {
    case persistDraftMood(DiaryEntryMood)
    case closeMoodSelection
  }

  override class func respond(to action: Action, state: inout State) -> Effect? {
    switch action {
    case .storeChanged(let storeState):
      if let draftMood = storeState.entryDraftMood {
        state.selectedMood = draftMood
        return nil
      }

      switch storeState.entrySelectionMode {
      case let .selecting(entry):
        state.selectedMood = entry.mood
      case .addingNew, .no:
        state.selectedMood = .okay
      }
      return nil

    case .selectedMoodChanged(let mood):
      state.selectedMood = mood
      return .persistDraftMood(mood)

    case .confirmSelection, .cancelSelection:
      return .closeMoodSelection
    }
  }

  override func handle(_ effect: Effect) async {
    switch effect {
    case .persistDraftMood(let mood):
      await updateStore { storeState in
        storeState.entryDraftMood = mood
      }
    case .closeMoodSelection:
      await updateStore { storeState in
        storeState.isSelectingEntryMood = false
      }
    }
  }
}
