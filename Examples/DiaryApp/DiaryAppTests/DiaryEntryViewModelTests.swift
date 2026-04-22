import XCTest
@testable import DiaryApp
@testable import Chiui

final class DiaryEntryViewModelTests: XCTestCase {
  var sut: DiaryEntryViewModel!
  var context: DiaryContext!

  override func setUp() async throws {
    try await super.setUp()
    await MainActor.run {
      context = DiaryContext(initialState: DiaryStoreState())
      sut = DiaryEntryViewModel(context)
    }
  }

  override func tearDown() async throws {
    await MainActor.run {
      sut = nil
      context = nil
    }
    try await super.tearDown()
  }

  // MARK: - State Tests

  @MainActor
  func testInitialState() async {
    XCTAssertEqual(sut.state.title, "")
    XCTAssertEqual(sut.state.content, "")
    XCTAssertEqual(sut.state.savingStatus, .no)
    XCTAssertFalse(sut.state.isEditing)
    XCTAssertFalse(sut.state.isDateSelectionPresented)
    XCTAssertFalse(sut.state.isMoodSelectionPresented)
    XCTAssertFalse(sut.state.isLocationSelectionPresented)
    XCTAssertEqual(sut.state.selectedMood, .okay)
    XCTAssertEqual(sut.state.selectedLocation, "")
    XCTAssertEqual(sut.state.entryTitle, "")
  }

  @MainActor
  func testIsSavingDisabled() async {
    await sut.sendAwaitingEffects(.titleChanged(""))
    XCTAssertTrue(sut.state.isSavingDisabled)

    await sut.sendAwaitingEffects(.titleChanged("Test Title"))
    XCTAssertFalse(sut.state.isSavingDisabled)

    await sut.sendAwaitingEffects(.finishRequested(save: true))
    XCTAssertFalse(sut.state.isSavingDisabled)
  }

  @MainActor
  func testUpdateTitle() async {
    await sut.sendAwaitingEffects(.startEditing)
    await sut.sendAwaitingEffects(.titleChanged("Test Title"))
    XCTAssertEqual(sut.state.title, "Test Title")
    XCTAssertTrue(sut.state.isEditing)
  }

  @MainActor
  func testUpdateContent() async {
    await sut.sendAwaitingEffects(.contentChanged("Test Content"))
    XCTAssertEqual(sut.state.content, "Test Content")
  }

  @MainActor
  func testStartEditing() async {
    await sut.sendAwaitingEffects(.startEditing)
    try? await Task.sleep(for: .seconds(0.1))
    XCTAssertTrue(sut.state.isEditing)
  }

  @MainActor
  func testFinishEditingWithoutSave() async {
    await sut.sendAwaitingEffects(.startEditing)
    await sut.sendAwaitingEffects(.titleChanged("Test Title"))
    await sut.sendAwaitingEffects(.contentChanged("Test Content"))
    XCTAssertTrue(sut.state.isEditing)

    await sut.sendAwaitingEffects(.finishRequested(save: false))
    XCTAssertFalse(sut.state.isEditing)
  }

  @MainActor
  func testFinishEditingWithSave() async {
    await sut.sendAwaitingEffects(.titleChanged("Test Title"))
    await sut.sendAwaitingEffects(.contentChanged("Test Content"))
    try? await Task.sleep(for: .seconds(0.1))
    XCTAssertFalse(sut.state.isEditing)

    await sut.sendAwaitingEffects(.startEditing)
    try? await Task.sleep(for: .seconds(0.1))
    XCTAssertTrue(sut.state.isEditing)

    await sut.sendAwaitingEffects(.finishRequested(save: true))
    XCTAssertEqual(sut.state.savingStatus, .saved)
    XCTAssertFalse(sut.state.isEditing)
  }

  @MainActor
  func testFinishEditingWithEmptyTitle() async {
    await sut.sendAwaitingEffects(.titleChanged(""))
    await sut.sendAwaitingEffects(.finishRequested(save: true))
    XCTAssertEqual(sut.state.savingStatus, .saved)
    XCTAssertFalse(sut.state.isEditing)
    let state = await context.store.state
    XCTAssertEqual(state.entries.count, 0)
  }

  @MainActor
  func testStoreUpdateOnNewEntry() async {
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
    XCTAssertEqual(state.entries.count, 1)
    let entry = state.entries[0]
    XCTAssertEqual(entry.title, "Test Title")
    XCTAssertEqual(entry.content, "Test Content")
    XCTAssertEqual(entry.createdAt, selectedDate)
    XCTAssertEqual(entry.mood, .great)
    XCTAssertEqual(entry.location, "Lisbon")
  }

  @MainActor
  func testStoreUpdateOnEditEntry() async {
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
    XCTAssertEqual(state.entries.count, 1)
    let entry = state.entries[0]
    XCTAssertEqual(entry.title, "Updated Title")
    XCTAssertEqual(entry.content, "Updated Content")
    XCTAssertEqual(entry.createdAt, updatedDate)
    XCTAssertEqual(entry.mood, .amazing)
    XCTAssertEqual(entry.location, "Prague")
  }

  @MainActor
  func testStoreStateMapping() async {
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
    }
    try? await Task.sleep(for: .seconds(0.2))
    XCTAssertEqual(sut.state.entryTitle, "New Entry")

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
    XCTAssertEqual(sut.state.entryTitle, "Test Title")
    XCTAssertEqual(sut.state.title, "Test Title")
    XCTAssertEqual(sut.state.content, "Test Content")
    XCTAssertEqual(sut.state.selectedDate, entry.createdAt)
    XCTAssertEqual(sut.state.selectedMood, entry.mood)
    XCTAssertEqual(sut.state.selectedLocation, entry.location)

    await context.store.update { state in
      state.entrySelectionMode = .no
    }
    try? await Task.sleep(for: .seconds(0.2))
    XCTAssertEqual(sut.state.entryTitle, "Test Title")
    XCTAssertEqual(sut.state.title, "Test Title")
    XCTAssertEqual(sut.state.content, "Test Content")
  }

  @MainActor
  func testOpenMoodSelectionSeedsDraftAndPresentsModal() async {
    await sut.sendAwaitingEffects(.selectedMoodChanged(.great))
    try? await Task.sleep(for: .seconds(0.1))

    await sut.sendAwaitingEffects(.openMoodSelection)
    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertTrue(sut.state.isMoodSelectionPresented)
    let storeState = await context.store.state
    XCTAssertTrue(storeState.isSelectingEntryMood)
    XCTAssertEqual(storeState.entryDraftMood, .great)
  }

  @MainActor
  func testUpdateSelectedMoodPersistsDraftMood() async {
    await sut.sendAwaitingEffects(.selectedMoodChanged(.amazing))
    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.state.selectedMood, .amazing)
    let storeState = await context.store.state
    XCTAssertEqual(storeState.entryDraftMood, .amazing)
  }

  @MainActor
  func testUpdateSelectedDatePersistsDraftDate() async {
    let date = Date(timeIntervalSince1970: 1_850_000_000)
    await sut.sendAwaitingEffects(.selectedDateChanged(date))

    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.state.selectedDate, date)
    let storeState = await context.store.state
    XCTAssertEqual(storeState.entryDraftDate, date)
  }

  @MainActor
  func testOpenLocationSelectionSeedsDraftAndPresentsModal() async {
    await sut.sendAwaitingEffects(.selectedLocationChanged("Vienna"))
    try? await Task.sleep(for: .seconds(0.1))

    await sut.sendAwaitingEffects(.openLocationSelection)
    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertTrue(sut.state.isLocationSelectionPresented)
    let storeState = await context.store.state
    XCTAssertTrue(storeState.isSelectingEntryLocation)
    XCTAssertEqual(storeState.entryDraftLocation, "Vienna")
  }

  @MainActor
  func testUpdateSelectedLocationPersistsDraftLocation() async {
    await sut.sendAwaitingEffects(.selectedLocationChanged("Seoul"))
    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.state.selectedLocation, "Seoul")
    let storeState = await context.store.state
    XCTAssertEqual(storeState.entryDraftLocation, "Seoul")
  }

  @MainActor
  func testReducerReturnsSaveEffect() async {
    var state = DiaryEntryViewModel.State()
    state.title = "Title"
    let effect = DiaryEntryViewModel.respond(to: .finishRequested(save: true), state: &state)
    XCTAssertEqual(state.savingStatus, .saving)
    guard case .performSave = effect else {
      XCTFail("Expected performSave effect")
      return
    }
  }
}
