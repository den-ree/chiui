import Foundation
import Chiui

final class DiaryEntryDateSelectionViewModel: ContextViewModel<
  DiaryContext,
  DiaryEntryDateSelectionViewModel.State,
  DiaryEntryDateSelectionViewModel.Action,
  DiaryEntryDateSelectionViewModel.Effect
> {
  struct State: ContextualViewState {
    var selectedDate: Date = .now
  }

  enum Action: ContextualAction {
    case storeChanged(DiaryContext.StoreState)
    case selectedDateChanged(Date)
    case confirmSelection
    case cancelSelection
  }

  enum Effect: Equatable {
    case persistDraftDate(Date)
    case closeDateSelection
  }

  override class func respond(to action: Action, state: inout State) -> Effect? {
    switch action {
    case .storeChanged(let storeState):
      if let draftDate = storeState.entryDraftDate {
        state.selectedDate = draftDate
        return nil
      }

      switch storeState.entrySelectionMode {
      case let .selecting(entry):
        state.selectedDate = entry.createdAt
      case .addingNew, .no:
        state.selectedDate = .now
      }
      return nil

    case .selectedDateChanged(let date):
      state.selectedDate = date
      return .persistDraftDate(date)

    case .confirmSelection, .cancelSelection:
      return .closeDateSelection
    }
  }

  override func handle(_ effect: Effect) async {
    switch effect {
    case .persistDraftDate(let date):
      await updateStore { storeState in
        storeState.entryDraftDate = date
      }
    case .closeDateSelection:
      await updateStore { storeState in
        storeState.isSelectingEntryDate = false
      }
    }
  }
}
