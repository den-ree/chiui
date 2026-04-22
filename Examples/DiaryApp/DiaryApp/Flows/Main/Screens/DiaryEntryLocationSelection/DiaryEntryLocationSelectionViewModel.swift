import Foundation
import Chiui

final class DiaryEntryLocationSelectionViewModel: ContextViewModel<
  DiaryContext,
  DiaryEntryLocationSelectionViewModel.State,
  DiaryEntryLocationSelectionViewModel.Action,
  DiaryEntryLocationSelectionViewModel.Effect
> {
  struct State: ContextualViewState {
    var location: String = ""
  }

  enum Action: Equatable, ContextualAction {
    case storeChanged(DiaryStoreState)
    case locationChanged(String)
    case confirmSelection
    case cancelSelection
  }

  enum Effect: Equatable {
    case persistDraftLocation(String)
    case closeLocationSelection
  }

  override class func respond(to action: Action, state: inout State) -> Effect? {
    switch action {
    case .storeChanged(let storeState):
      if let draftLocation = storeState.entryDraftLocation {
        state.location = draftLocation
        return nil
      }

      switch storeState.entrySelectionMode {
      case let .selecting(entry):
        state.location = entry.location
      case .addingNew, .no:
        state.location = ""
      }
      return nil

    case .locationChanged(let location):
      state.location = location
      return .persistDraftLocation(location)

    case .confirmSelection, .cancelSelection:
      return .closeLocationSelection
    }
  }

  override func handle(_ effect: Effect) async {
    switch effect {
    case .persistDraftLocation(let location):
      await updateStore { storeState in
        storeState.entryDraftLocation = location
      }

    case .closeLocationSelection:
      await updateStore { storeState in
        storeState.isSelectingEntryLocation = false
      }
    }
  }
}
