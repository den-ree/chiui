import Foundation
import Chiui

final class DiaryListViewModel: ContextViewModel<
  DiaryContext,
  DiaryListViewModel.State,
  DiaryListViewModel.Action,
  DiaryListViewModel.Effect
> {
  struct State: ContextualViewState {
    var entries: [DiaryEntry] = []
    var selectedEntryId: UUID?
    var isAddingNew: Bool = false
    var isRefreshing: Bool = false

    func entry(at index: Int) -> DiaryEntry {
      entries[index]
    }

    init() {}
  }

  enum Action: Equatable, ContextualAction {
    case storeChanged(DiaryStoreState)
    case selectEntry(DiaryEntry)
    case clearSelection
    case setEntryDestinationPresented(Bool)
    case startAddingNew
    case finishAddingNew
    case setAddingNewDestinationPresented(Bool)
    case removeEntryAt(Int)
    case removeEntryById(UUID)
    case refresh
  }

  enum Effect {
    case selectEntry(DiaryEntry)
    case clearSelection
    case startAddingNew
    case finishAddingNew
    case removeEntry(UUID)
  }

  override class func respond(to action: Action, state: inout State) -> Effect? {
    switch action {
    case .storeChanged(let storeState):
      state.entries = storeState.entries.sorted { $0.createdAt > $1.createdAt }
      state.isAddingNew = storeState.entrySelectionMode == .addingNew
      if case let .selecting(selectedEntry) = storeState.entrySelectionMode {
        state.selectedEntryId = selectedEntry.id
      } else {
        state.selectedEntryId = nil
      }
      return nil

    case .selectEntry(let entry):
      return .selectEntry(entry)

    case .clearSelection:
      return .clearSelection

    case .setEntryDestinationPresented(let isPresented):
      return isPresented ? nil : .clearSelection

    case .startAddingNew:
      return .startAddingNew

    case .finishAddingNew:
      return .finishAddingNew

    case .setAddingNewDestinationPresented(let isPresented):
      return isPresented ? nil : .finishAddingNew

    case .removeEntryAt(let index):
      guard state.entries.indices.contains(index) else { return nil }
      return .removeEntry(state.entries[index].id)

    case .removeEntryById(let id):
      return .removeEntry(id)

    case .refresh:
      state.isRefreshing = true
      return nil
    }
  }

  override func handle(_ effect: Effect) async {
    switch effect {
    case .selectEntry(let entry):
      await updateStore { storeState in
        storeState.entrySelectionMode = .selecting(entry)
      }

    case .clearSelection:
      await updateStore { storeState in
        storeState.entrySelectionMode = .no
      }

    case .startAddingNew:
      await updateStore { storeState in
        storeState.entrySelectionMode = .addingNew
      }

    case .finishAddingNew:
      await updateStore { storeState in
        if storeState.entrySelectionMode == .addingNew {
          storeState.entrySelectionMode = .no
        }
      }

    case .removeEntry(let id):
      await updateStore { storeState in
        storeState.entries.removeAll { $0.id == id }
      }
    }
  }
}
