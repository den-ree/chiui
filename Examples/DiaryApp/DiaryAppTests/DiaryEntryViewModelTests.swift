import Foundation
import Testing
@testable import DiaryApp
@testable import Chiui

@Suite("DiaryEntryViewModel tests")
struct DiaryEntryViewModelTests {
  @MainActor
  private func makeSUT() -> (sut: DiaryEntryViewModel, context: DiaryContext) {
    let context = DiaryContext(initialState: DiaryStoreState())
    let sut = DiaryEntryViewModel(context)
    return (sut, context)
  }

  @Test("Initial state")
  @MainActor
  func initialState() async {
    let (sut, _) = makeSUT()
    #expect(sut.state.title == "")
    #expect(sut.state.content == "")
    #expect(sut.state.savingStatus == .no)
    #expect(sut.state.isEditing == false)
    #expect(sut.state.isDateSelectionPresented == false)
    #expect(sut.state.isMoodSelectionPresented == false)
    #expect(sut.state.isLocationSelectionPresented == false)
    #expect(sut.state.selectedMood == .okay)
    #expect(sut.state.selectedLocation == "")
    #expect(sut.state.entryTitle == "")
  }

  @Test("isSavingDisabled reflects title and save flow")
  @MainActor
  func isSavingDisabled() async {
    let (sut, _) = makeSUT()
    await sut.sendAwaitingEffects(.titleChanged(""))
    #expect(sut.state.isSavingDisabled)

    await sut.sendAwaitingEffects(.titleChanged("Test Title"))
    #expect(sut.state.isSavingDisabled == false)

    await sut.sendAwaitingEffects(.finishRequested(save: true))
    #expect(sut.state.isSavingDisabled == false)
  }

  @Test("titleChanged updates title")
  @MainActor
  func updateTitle() async {
    let (sut, _) = makeSUT()
    await sut.sendAwaitingEffects(.startEditing)
    await sut.sendAwaitingEffects(.titleChanged("Test Title"))
    #expect(sut.state.title == "Test Title")
    #expect(sut.state.isEditing)
  }

  @Test("contentChanged updates content")
  @MainActor
  func updateContent() async {
    let (sut, _) = makeSUT()
    await sut.sendAwaitingEffects(.contentChanged("Test Content"))
    #expect(sut.state.content == "Test Content")
  }

  @Test("startEditing enables editing mode")
  @MainActor
  func startEditing() async {
    let (sut, _) = makeSUT()
    await sut.sendAwaitingEffects(.startEditing)
    try? await Task.sleep(for: .seconds(0.1))
    #expect(sut.state.isEditing)
  }

  @Test("finishRequested without save exits editing mode")
  @MainActor
  func finishEditingWithoutSave() async {
    let (sut, _) = makeSUT()
    await sut.sendAwaitingEffects(.startEditing)
    await sut.sendAwaitingEffects(.titleChanged("Test Title"))
    await sut.sendAwaitingEffects(.contentChanged("Test Content"))
    #expect(sut.state.isEditing)

    await sut.sendAwaitingEffects(.finishRequested(save: false))
    #expect(sut.state.isEditing == false)
  }

  @Test("finishRequested with save marks state as saved")
  @MainActor
  func finishEditingWithSave() async {
    let (sut, _) = makeSUT()
    await sut.sendAwaitingEffects(.titleChanged("Test Title"))
    await sut.sendAwaitingEffects(.contentChanged("Test Content"))
    try? await Task.sleep(for: .seconds(0.1))
    #expect(sut.state.isEditing == false)

    await sut.sendAwaitingEffects(.startEditing)
    try? await Task.sleep(for: .seconds(0.1))
    #expect(sut.state.isEditing)

    await sut.sendAwaitingEffects(.finishRequested(save: true))
    #expect(sut.state.savingStatus == .saved)
    #expect(sut.state.isEditing == false)
  }

  @Test("Saving empty title does not append entries")
  @MainActor
  func finishEditingWithEmptyTitle() async {
    let (sut, context) = makeSUT()
    await sut.sendAwaitingEffects(.titleChanged(""))
    await sut.sendAwaitingEffects(.finishRequested(save: true))
    #expect(sut.state.savingStatus == .saved)
    #expect(sut.state.isEditing == false)
    let state = await context.store.state
    #expect(state.entries.count == 0)
  }

  @Test("Saving new entry writes full payload to store")
  @MainActor
  func storeUpdateOnNewEntry() async {
    let (sut, context) = makeSUT()
    let selectedDate = Date(timeIntervalSince1970: 1_700_000_000)
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
      state.entryDraftDate = selectedDate
      state.entryDraftMood = .great
      state.entryDraftLocation = "Lisbon"
    }
    try? await Task.sleep(for: .seconds(0.1))
    await sut.sendAwaitingEffects(.titleChanged("Test Title"))
    await sut.sendAwaitingEffects(.contentChanged("Test Content"))
    await sut.sendAwaitingEffects(.finishRequested(save: true))

    try? await Task.sleep(for: .seconds(2.1))

    let state = await context.store.state
    #expect(state.entries.count == 1)
    let entry = state.entries[0]
    #expect(entry.title == "Test Title")
    #expect(entry.content == "Test Content")
    #expect(entry.createdAt == selectedDate)
    #expect(entry.mood == .great)
    #expect(entry.location == "Lisbon")
  }

  @Test("Saving edited entry updates existing row")
  @MainActor
  func storeUpdateOnEditEntry() async {
    let (sut, context) = makeSUT()
    let initialEntry = DiaryEntry(
      id: UUID(),
      title: "Initial Title",
      content: "Initial Content",
      createdAt: .now,
      mood: .bad,
      location: "Paris"
    )
    let updatedDate = Date(timeIntervalSince1970: 1_800_000_000)
    await context.store.update { state in
      state.entries = [initialEntry]
      state.entrySelectionMode = .selecting(initialEntry)
      state.entryDraftDate = updatedDate
      state.entryDraftMood = .amazing
      state.entryDraftLocation = "Prague"
    }

    try? await Task.sleep(for: .seconds(0.1))

    await sut.sendAwaitingEffects(.titleChanged("Updated Title"))
    await sut.sendAwaitingEffects(.contentChanged("Updated Content"))
    await sut.sendAwaitingEffects(.finishRequested(save: true))

    try? await Task.sleep(for: .seconds(2.1))

    let state = await context.store.state
    #expect(state.entries.count == 1)
    let entry = state.entries[0]
    #expect(entry.title == "Updated Title")
    #expect(entry.content == "Updated Content")
    #expect(entry.createdAt == updatedDate)
    #expect(entry.mood == .amazing)
    #expect(entry.location == "Prague")
  }

  @Test("Store mapping updates local state from selection mode")
  @MainActor
  func storeStateMapping() async {
    let (sut, context) = makeSUT()
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
    }
    try? await Task.sleep(for: .seconds(0.2))
    #expect(sut.state.entryTitle == "New Entry")

    let entry = DiaryEntry(
      id: UUID(),
      title: "Test Title",
      content: "Test Content",
      createdAt: .now,
      mood: .good,
      location: "Stockholm"
    )
    await context.store.update { state in
      state.entrySelectionMode = .selecting(entry)
    }
    try? await Task.sleep(for: .seconds(0.2))
    #expect(sut.state.entryTitle == "Test Title")
    #expect(sut.state.title == "Test Title")
    #expect(sut.state.content == "Test Content")
    #expect(sut.state.selectedDate == entry.createdAt)
    #expect(sut.state.selectedMood == entry.mood)
    #expect(sut.state.selectedLocation == entry.location)

    await context.store.update { state in
      state.entrySelectionMode = .no
    }
    try? await Task.sleep(for: .seconds(0.2))
    #expect(sut.state.entryTitle == "Test Title")
    #expect(sut.state.title == "Test Title")
    #expect(sut.state.content == "Test Content")
  }

  @Test("openMoodSelection seeds draft and presents modal")
  @MainActor
  func openMoodSelectionSeedsDraftAndPresentsModal() async {
    let (sut, context) = makeSUT()
    await sut.sendAwaitingEffects(.selectedMoodChanged(.great))
    try? await Task.sleep(for: .seconds(0.1))

    await sut.sendAwaitingEffects(.openMoodSelection)
    try? await Task.sleep(for: .seconds(0.1))

    #expect(sut.state.isMoodSelectionPresented)
    let storeState = await context.store.state
    #expect(storeState.isSelectingEntryMood)
    #expect(storeState.entryDraftMood == .great)
  }

  @Test("selectedMoodChanged persists draft mood")
  @MainActor
  func updateSelectedMoodPersistsDraftMood() async {
    let (sut, context) = makeSUT()
    await sut.sendAwaitingEffects(.selectedMoodChanged(.amazing))
    try? await Task.sleep(for: .seconds(0.1))

    #expect(sut.state.selectedMood == .amazing)
    let storeState = await context.store.state
    #expect(storeState.entryDraftMood == .amazing)
  }

  @Test("selectedDateChanged persists draft date")
  @MainActor
  func updateSelectedDatePersistsDraftDate() async {
    let (sut, context) = makeSUT()
    let date = Date(timeIntervalSince1970: 1_850_000_000)
    await sut.sendAwaitingEffects(.selectedDateChanged(date))

    try? await Task.sleep(for: .seconds(0.1))

    #expect(sut.state.selectedDate == date)
    let storeState = await context.store.state
    #expect(storeState.entryDraftDate == date)
  }

  @Test("openLocationSelection seeds draft and presents modal")
  @MainActor
  func openLocationSelectionSeedsDraftAndPresentsModal() async {
    let (sut, context) = makeSUT()
    await sut.sendAwaitingEffects(.selectedLocationChanged("Vienna"))
    try? await Task.sleep(for: .seconds(0.1))

    await sut.sendAwaitingEffects(.openLocationSelection)
    try? await Task.sleep(for: .seconds(0.1))

    #expect(sut.state.isLocationSelectionPresented)
    let storeState = await context.store.state
    #expect(storeState.isSelectingEntryLocation)
    #expect(storeState.entryDraftLocation == "Vienna")
  }

  @Test("selectedLocationChanged persists draft location")
  @MainActor
  func updateSelectedLocationPersistsDraftLocation() async {
    let (sut, context) = makeSUT()
    await sut.sendAwaitingEffects(.selectedLocationChanged("Seoul"))
    try? await Task.sleep(for: .seconds(0.1))

    #expect(sut.state.selectedLocation == "Seoul")
    let storeState = await context.store.state
    #expect(storeState.entryDraftLocation == "Seoul")
  }

  @Test("Reducer emits performSave effect for finishRequested(save: true)")
  @MainActor
  func reducerReturnsSaveEffect() async {
    var state = DiaryEntryViewModel.State()
    state.title = "Title"
    let effect = DiaryEntryViewModel.respond(to: .finishRequested(save: true), state: &state)
    #expect(state.savingStatus == .saving)
    #expect({
      if case .performSave? = effect {
        return true
      }
      return false
    }())
  }
}
