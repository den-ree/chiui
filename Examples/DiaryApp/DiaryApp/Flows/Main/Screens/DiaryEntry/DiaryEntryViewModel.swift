import Foundation
import Chiui

final class DiaryEntryViewModel: ContextViewModel<
  DiaryContext,
  DiaryEntryViewModel.State,
  DiaryEntryViewModel.Action,
  DiaryEntryViewModel.Effect
> {
  enum SavingStatus: Equatable {
    case no
    case saving
    case saved
  }

  struct State: ContextualViewState {
    var title: String = ""
    var content: String = ""
    var selectedDate: Date = .now
    var selectedMood: DiaryEntryMood = .okay
    var selectedLocation: String = ""
    var savingStatus: SavingStatus = .no
    var isEditing: Bool = false
    var isDateSelectionPresented: Bool = false
    var isMoodSelectionPresented: Bool = false
    var isLocationSelectionPresented: Bool = false
    var entryTitle: String = ""

    var isSavingDisabled: Bool {
      title.isEmpty || savingStatus == .saving
    }

    var isSaved: Bool {
      savingStatus == .saved
    }

    init() {}
  }

  enum Action: Equatable, ContextualAction {
    case storeChanged(DiaryStoreState)
    case titleChanged(String)
    case contentChanged(String)
    case startEditing
    case openDateSelection
    case openMoodSelection
    case openLocationSelection
    case selectedMoodChanged(DiaryEntryMood)
    case selectedDateChanged(Date)
    case selectedLocationChanged(String)
    case finishRequested(save: Bool)
    case saveCompleted
  }

  struct SavePayload {
    let title: String
    let content: String
    let selectedDate: Date
    let selectedMood: DiaryEntryMood
    let selectedLocation: String
  }

  enum Effect {
    case openDateSelection(Date)
    case openMoodSelection(DiaryEntryMood)
    case openLocationSelection(String)
    case persistDraftMood(DiaryEntryMood)
    case persistDraftDate(Date)
    case persistDraftLocation(String)
    case closeEntrySelection
    case performSave(SavePayload)
    case resetSelectionState
  }

  override class func respond(to action: Action, state: inout State) -> Effect? {
    if case let .storeChanged(storeState) = action {
      applyStoreState(storeState, to: &state)
      return nil
    }
    if case let .finishRequested(save) = action {
      return respondToFinishRequested(save: save, state: &state)
    }
    if case .saveCompleted = action {
      state.savingStatus = .saved
      state.isEditing = false
      return .resetSelectionState
    }
    return respondToEditingAction(action, state: &state)
  }

  private class func applyStoreState(_ storeState: DiaryStoreState, to state: inout State) {
    guard state.savingStatus != .saving else { return }

    switch storeState.entrySelectionMode {
    case .addingNew:
      state.entryTitle = "New Entry"
      state.selectedDate = storeState.entryDraftDate ?? .now
      state.selectedMood = storeState.entryDraftMood ?? .okay
      state.selectedLocation = storeState.entryDraftLocation ?? ""
    case let .selecting(entry):
      state.title = entry.title
      state.content = entry.content
      state.selectedDate = storeState.entryDraftDate ?? entry.createdAt
      state.selectedMood = storeState.entryDraftMood ?? entry.mood
      state.selectedLocation = storeState.entryDraftLocation ?? entry.location
      state.entryTitle = entry.title
    case .no:
      break
    }

    state.isDateSelectionPresented = storeState.isSelectingEntryDate
    state.isMoodSelectionPresented = storeState.isSelectingEntryMood
    state.isLocationSelectionPresented = storeState.isSelectingEntryLocation
  }

  private class func respondToEditingAction(_ action: Action, state: inout State) -> Effect? {
    switch action {
    case .titleChanged(let title):
      state.title = title
      return nil

    case .contentChanged(let content):
      state.content = content
      return nil

    case .startEditing:
      state.isEditing = true
      return nil

    case .openDateSelection:
      state.isEditing = true
      return .openDateSelection(state.selectedDate)

    case .openMoodSelection:
      state.isEditing = true
      return .openMoodSelection(state.selectedMood)

    case .openLocationSelection:
      state.isEditing = true
      return .openLocationSelection(state.selectedLocation)

    case .selectedMoodChanged(let mood):
      state.selectedMood = mood
      state.isEditing = true
      return .persistDraftMood(mood)

    case .selectedDateChanged(let date):
      state.selectedDate = date
      state.isEditing = true
      return .persistDraftDate(date)

    case .selectedLocationChanged(let location):
      state.selectedLocation = location
      state.isEditing = true
      return .persistDraftLocation(location)

    case .storeChanged, .finishRequested, .saveCompleted:
      return nil
    }
  }

  private class func respondToFinishRequested(save: Bool, state: inout State) -> Effect? {
    guard save else {
      state.isEditing = false
      return .closeEntrySelection
    }

    state.savingStatus = .saving
    let payload = SavePayload(
      title: state.title,
      content: state.content,
      selectedDate: state.selectedDate,
      selectedMood: state.selectedMood,
      selectedLocation: state.selectedLocation
    )
    return .performSave(payload)
  }

  override func handle(_ effect: Effect) async {
    if case let .performSave(payload) = effect {
      await performSave(payload)
      return
    }
    if case .resetSelectionState = effect {
      await resetSelectionState()
      return
    }

    switch effect {
    case .openDateSelection(let date):
      await openDateSelection(with: date)

    case .openMoodSelection(let mood):
      await openMoodSelection(with: mood)

    case .openLocationSelection(let location):
      await openLocationSelection(with: location)

    case .persistDraftMood(let mood):
      await persistDraftMood(mood)

    case .persistDraftDate(let date):
      await persistDraftDate(date)

    case .persistDraftLocation(let location):
      await persistDraftLocation(location)

    case .closeEntrySelection:
      await closeEntrySelection()

    case .performSave, .resetSelectionState:
      break
    }
  }

  private func openDateSelection(with date: Date) async {
    await updateStore { storeState in
      storeState.entryDraftDate = date
      storeState.isSelectingEntryDate = true
    }
  }

  private func openMoodSelection(with mood: DiaryEntryMood) async {
    await updateStore { storeState in
      storeState.entryDraftMood = mood
      storeState.isSelectingEntryMood = true
    }
  }

  private func openLocationSelection(with location: String) async {
    await updateStore { storeState in
      storeState.entryDraftLocation = location
      storeState.isSelectingEntryLocation = true
    }
  }

  private func persistDraftMood(_ mood: DiaryEntryMood) async {
    await updateStore { storeState in
      storeState.entryDraftMood = mood
    }
  }

  private func persistDraftDate(_ date: Date) async {
    await updateStore { storeState in
      storeState.entryDraftDate = date
    }
  }

  private func persistDraftLocation(_ location: String) async {
    await updateStore { storeState in
      storeState.entryDraftLocation = location
    }
  }

  private func closeEntrySelection() async {
    await updateStore { storeState in
      storeState.entrySelectionMode = .no
    }
  }

  private func performSave(_ payload: SavePayload) async {
    let newEntry = DiaryEntry(
      id: .init(),
      title: payload.title,
      content: payload.content,
      createdAt: payload.selectedDate,
      mood: payload.selectedMood,
      location: payload.selectedLocation
    )

    await updateStore { storeState in
      Self.applySavePayload(payload, newEntry: newEntry, to: &storeState)
    }
    await context.loadingClient.simulateLoadingWork()
    send(.saveCompleted)
  }

  private class func applySavePayload(
    _ payload: SavePayload,
    newEntry: DiaryEntry,
    to storeState: inout DiaryStoreState
  ) {
    switch storeState.entrySelectionMode {
    case .addingNew:
      if !payload.title.isEmpty {
        storeState.entries.append(newEntry)
      }
    case let .selecting(existingEntry):
      let updatedEntry = existingEntry.new(
        title: newEntry.title,
        content: newEntry.content,
        createdAt: payload.selectedDate,
        mood: payload.selectedMood,
        location: payload.selectedLocation
      )
      storeState.entries = storeState.entries.map { $0.id == existingEntry.id ? updatedEntry : $0 }
    case .no:
      break
    }
  }

  private func resetSelectionState() async {
    await updateStore { storeState in
      storeState.entrySelectionMode = .no
      storeState.isSelectingEntryDate = false
      storeState.isSelectingEntryMood = false
      storeState.isSelectingEntryLocation = false
      storeState.entryDraftDate = nil
      storeState.entryDraftMood = nil
      storeState.entryDraftLocation = nil
    }
  }
}
