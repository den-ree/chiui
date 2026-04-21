import Foundation
import Chiui
import SwiftUI

final class DiaryListViewModel: ContextViewModel<DiaryContext, DiaryListViewModel.State> {
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

  override init(_ context: DiaryContext) {
    super.init(context)
  }

  nonisolated override func didStoreUpdate(
    _ storeState: DiaryStoreState
  ) async {
    await updateState { state in
      state.entries = storeState.entries.sorted { $0.createdAt > $1.createdAt }
      state.isAddingNew = storeState.entrySelectionMode == .addingNew
      if case let .selecting(selectedEntry) = storeState.entrySelectionMode {
        state.selectedEntryId = selectedEntry.id
      } else {
        state.selectedEntryId = nil
      }
    }
  }

  func selectEntry(_ entry: DiaryEntry) {
    updateStore { storeState in
      storeState.entrySelectionMode = .selecting(entry)
    }
  }

  func clearSelection() {
    updateStore { storeState in
      storeState.entrySelectionMode = .no
    }
  }

  func isEntryDestinationPresented() -> Bool {
    state.selectedEntryId != nil
  }

  func setEntryDestinationPresented(_ isPresented: Bool) {
    if !isPresented {
      clearSelection()
    }
  }

  func startAddingNew() {
    updateStore { storeState in
      storeState.entrySelectionMode = .addingNew
    }
  }

  func finishAddingNew() {
    updateStore { storeState in
      if storeState.entrySelectionMode == .addingNew {
        storeState.entrySelectionMode = .no
      }
    }
  }

  func setAddingNewDestinationPresented(_ isPresented: Bool) {
    if !isPresented {
      finishAddingNew()
    }
  }

  func removeEntry(at index: Int) {
    Task {
      await scopeState({ $0 }, { [weak self] state in
        let entry = state.entry(at: index)

        self?.updateStore { storeState in
          storeState.entries.removeAll { $0.id == entry.id }
        }
      })
    }
  }

  func removeEntryById(_ id: UUID) {
    updateStore { storeState in
      storeState.entries.removeAll { $0.id == id }
    }
  }

  func refresh() {
    updateState { state in
      state.isRefreshing = true
    }
  }
}
