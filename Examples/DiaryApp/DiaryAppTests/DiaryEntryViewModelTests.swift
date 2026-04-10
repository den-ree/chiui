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
    XCTAssertEqual(sut.viewState.entryTitle, "")
  }

  @MainActor
  func testIsSavingDisabled() async {
    // Empty title should disable saving
    sut.updateTitle("")
    XCTAssertTrue(sut.viewState.isSavingDisabled)

    // Non-empty title should enable saving
    sut.updateTitle("Test Title")
    XCTAssertFalse(sut.viewState.isSavingDisabled)

    // Saving in progress should disable saving
    await sut.finishEditing(save: true)
    XCTAssertFalse(sut.viewState.isSavingDisabled)
  }

  // MARK: - Action Tests

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
    // Setup initial editing state
    sut.startEditing()
    sut.updateTitle("Test Title")
    sut.updateContent("Test Content")
    XCTAssertTrue(sut.viewState.isEditing)

    // Cancel editing
    await sut.finishEditing(save: false)
    XCTAssertFalse(sut.viewState.isEditing)
  }

  @MainActor
  func testFinishEditingWithSave() async {
    // Setup initial editing state
    sut.updateTitle("Test Title")
    sut.updateContent("Test Content")
    try? await Task.sleep(for: .seconds(0.1))
    XCTAssertFalse(sut.viewState.isEditing)

    sut.startEditing()
    try? await Task.sleep(for: .seconds(0.1))
    XCTAssertTrue(sut.viewState.isEditing)

    // Save entry
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

  // MARK: - Store Integration Tests

  @MainActor
  func testStoreUpdateOnNewEntry() async {
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
    }
    try? await Task.sleep(for: .seconds(0.1))
    sut.updateTitle("Test Title")
    sut.updateContent("Test Content")
    await sut.finishEditing(save: true)

    // Wait for saving to complete
    try? await Task.sleep(for: .seconds(2.1))

    let state = await context.store.state
    XCTAssertEqual(state.entries.count, 1)
    let entry = state.entries[0]
    XCTAssertEqual(entry.title, "Test Title")
    XCTAssertEqual(entry.content, "Test Content")
  }

  @MainActor
  func testStoreUpdateOnEditEntry() async {
    // Create initial entry
    let initialEntry = DiaryEntry(
      id: UUID(),
      title: "Initial Title",
      content: "Initial Content",
      createdAt: .now
    )
    await context.store.update { state in
      state.entries = [initialEntry]
      state.entrySelectionMode = .selecting(initialEntry)
    }

    try? await Task.sleep(for: .seconds(0.1))

    // Edit entry
    sut.updateTitle("Updated Title")
    sut.updateContent("Updated Content")
    await sut.finishEditing(save: true)

    // Wait for saving to complete
    try? await Task.sleep(for: .seconds(2.1))

    let state = await context.store.state
    XCTAssertEqual(state.entries.count, 1)
    let entry = state.entries[0]
    XCTAssertEqual(entry.title, "Updated Title")
    XCTAssertEqual(entry.content, "Updated Content")
  }

  @MainActor
  func testStoreStateMapping() async {
    // Test adding new mode
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
    }
    // Wait for saving to complete
    try? await Task.sleep(for: .seconds(0.2))
    XCTAssertEqual(sut.viewState.entryTitle, "New Entry")

    // Test selecting mode
    let entry = DiaryEntry(
      id: UUID(),
      title: "Test Title",
      content: "Test Content",
      createdAt: .now
    )
    await context.store.update { state in
      state.entrySelectionMode = .selecting(entry)
    }
    // Wait for saving to complete
    try? await Task.sleep(for: .seconds(0.2))
    XCTAssertEqual(sut.viewState.entryTitle, "Test Title")
    XCTAssertEqual(sut.viewState.title, "Test Title")
    XCTAssertEqual(sut.viewState.content, "Test Content")

    // Test no selection mode
    await context.store.update { state in
      state.entrySelectionMode = .no
    }
    // Wait for saving to complete
    try? await Task.sleep(for: .seconds(0.2))
    XCTAssertEqual(sut.viewState.entryTitle, "Test Title")
    XCTAssertEqual(sut.viewState.title, "Test Title")
    XCTAssertEqual(sut.viewState.content, "Test Content")
  }
}
