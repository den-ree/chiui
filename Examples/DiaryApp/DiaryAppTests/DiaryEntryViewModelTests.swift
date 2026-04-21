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
    XCTAssertEqual(sut.viewState.title, "")
    XCTAssertEqual(sut.viewState.content, "")
    XCTAssertEqual(sut.viewState.savingStatus, .no)
    XCTAssertFalse(sut.viewState.isEditing)
    XCTAssertFalse(sut.viewState.isDateSelectionPresented)
    XCTAssertFalse(sut.viewState.isMoodSelectionPresented)
    XCTAssertEqual(sut.viewState.selectedMood, .okay)
    XCTAssertEqual(sut.viewState.entryTitle, "")
  }

  @MainActor
  func testIsSavingDisabled() async {
    sut.updateTitle("")
    XCTAssertTrue(sut.viewState.isSavingDisabled)

    sut.updateTitle("Test Title")
    XCTAssertFalse(sut.viewState.isSavingDisabled)

    await sut.finishEditing(save: true)
    XCTAssertFalse(sut.viewState.isSavingDisabled)
  }

  @MainActor
  func testUpdateTitle() async {
    sut.startEditing()
    sut.updateTitle("Test Title")
    XCTAssertEqual(sut.viewState.title, "Test Title")
    XCTAssertTrue(sut.viewState.isEditing)
  }

  @MainActor
  func testUpdateContent() async {
    sut.updateContent("Test Content")
    XCTAssertEqual(sut.viewState.content, "Test Content")
  }

  @MainActor
  func testStartEditing() async {
    sut.startEditing()
    try? await Task.sleep(for: .seconds(0.1))
    XCTAssertTrue(sut.viewState.isEditing)
  }

  @MainActor
  func testFinishEditingWithoutSave() async {
    sut.startEditing()
    sut.updateTitle("Test Title")
    sut.updateContent("Test Content")
    XCTAssertTrue(sut.viewState.isEditing)

    await sut.finishEditing(save: false)
    XCTAssertFalse(sut.viewState.isEditing)
  }

  @MainActor
  func testFinishEditingWithSave() async {
    sut.updateTitle("Test Title")
    sut.updateContent("Test Content")
    try? await Task.sleep(for: .seconds(0.1))
    XCTAssertFalse(sut.viewState.isEditing)

    sut.startEditing()
    try? await Task.sleep(for: .seconds(0.1))
    XCTAssertTrue(sut.viewState.isEditing)

    await sut.finishEditing(save: true)
    XCTAssertEqual(sut.viewState.savingStatus, .saved)
    XCTAssertFalse(sut.viewState.isEditing)
  }

  @MainActor
  func testFinishEditingWithEmptyTitle() async {
    sut.updateTitle("")
    await sut.finishEditing(save: true)
    XCTAssertEqual(sut.viewState.savingStatus, .saved)
    XCTAssertFalse(sut.viewState.isEditing)
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
    }
    try? await Task.sleep(for: .seconds(0.1))
    sut.updateTitle("Test Title")
    sut.updateContent("Test Content")
    await sut.finishEditing(save: true)

    try? await Task.sleep(for: .seconds(2.1))

    let state = await context.store.state
    XCTAssertEqual(state.entries.count, 1)
    let entry = state.entries[0]
    XCTAssertEqual(entry.title, "Test Title")
    XCTAssertEqual(entry.content, "Test Content")
    XCTAssertEqual(entry.createdAt, selectedDate)
    XCTAssertEqual(entry.mood, .great)
  }

  @MainActor
  func testStoreUpdateOnEditEntry() async {
    let initialEntry = DiaryEntry(
      id: UUID(),
      title: "Initial Title",
      content: "Initial Content",
      createdAt: .now,
      mood: .bad
    )
    let updatedDate = Date(timeIntervalSince1970: 1_800_000_000)
    await context.store.update { state in
      state.entries = [initialEntry]
      state.entrySelectionMode = .selecting(initialEntry)
      state.entryDraftDate = updatedDate
      state.entryDraftMood = .amazing
    }

    try? await Task.sleep(for: .seconds(0.1))

    sut.updateTitle("Updated Title")
    sut.updateContent("Updated Content")
    await sut.finishEditing(save: true)

    try? await Task.sleep(for: .seconds(2.1))

    let state = await context.store.state
    XCTAssertEqual(state.entries.count, 1)
    let entry = state.entries[0]
    XCTAssertEqual(entry.title, "Updated Title")
    XCTAssertEqual(entry.content, "Updated Content")
    XCTAssertEqual(entry.createdAt, updatedDate)
    XCTAssertEqual(entry.mood, .amazing)
  }

  @MainActor
  func testStoreStateMapping() async {
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
    }
    try? await Task.sleep(for: .seconds(0.2))
    XCTAssertEqual(sut.viewState.entryTitle, "New Entry")

    let entry = DiaryEntry(
      id: UUID(),
      title: "Test Title",
      content: "Test Content",
      createdAt: .now,
      mood: .good
    )
    await context.store.update { state in
      state.entrySelectionMode = .selecting(entry)
    }
    try? await Task.sleep(for: .seconds(0.2))
    XCTAssertEqual(sut.viewState.entryTitle, "Test Title")
    XCTAssertEqual(sut.viewState.title, "Test Title")
    XCTAssertEqual(sut.viewState.content, "Test Content")
    XCTAssertEqual(sut.viewState.selectedDate, entry.createdAt)
    XCTAssertEqual(sut.viewState.selectedMood, entry.mood)

    await context.store.update { state in
      state.entrySelectionMode = .no
    }
    try? await Task.sleep(for: .seconds(0.2))
    XCTAssertEqual(sut.viewState.entryTitle, "Test Title")
    XCTAssertEqual(sut.viewState.title, "Test Title")
    XCTAssertEqual(sut.viewState.content, "Test Content")
  }

  @MainActor
  func testOpenMoodSelectionSeedsDraftAndPresentsModal() async {
    sut.updateSelectedMood(.great)
    try? await Task.sleep(for: .seconds(0.1))

    sut.openMoodSelection()
    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertTrue(sut.viewState.isMoodSelectionPresented)
    let storeState = await context.store.state
    XCTAssertTrue(storeState.isSelectingEntryMood)
    XCTAssertEqual(storeState.entryDraftMood, .great)
  }

  @MainActor
  func testUpdateSelectedMoodPersistsDraftMood() async {
    sut.updateSelectedMood(.amazing)
    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.viewState.selectedMood, .amazing)
    let storeState = await context.store.state
    XCTAssertEqual(storeState.entryDraftMood, .amazing)
  }

  @MainActor
  func testUpdateSelectedDatePersistsDraftDate() async {
    let date = Date(timeIntervalSince1970: 1_850_000_000)
    sut.updateSelectedDate(date)

    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.viewState.selectedDate, date)
    let storeState = await context.store.state
    XCTAssertEqual(storeState.entryDraftDate, date)
  }
}
