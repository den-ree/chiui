import XCTest
@testable import DiaryApp
@testable import Chiui

final class DiaryEntryViewModelTests: XCTestCase {
  var sut: DiaryEntryViewModel!
  var context: DiaryContext!

  override func setUp() async throws {
    try await super.setUp()
    context = DiaryContext(initialState: DiaryStoreState())
    sut = DiaryEntryViewModel(context)
  }

  override func tearDown() async throws {
    sut = nil
    context = nil
    try await super.tearDown()
  }

  // MARK: - State Tests

  func testInitialState() async {
    XCTAssertEqual(sut.viewState.title, "")
    XCTAssertEqual(sut.viewState.content, "")
    XCTAssertEqual(sut.viewState.savingStatus, .no)
    XCTAssertFalse(sut.viewState.isEditing)
    XCTAssertEqual(sut.viewState.entryTitle, "")
    XCTAssertFalse(sut.viewState.shouldDismiss)
  }

  func testIsSavingDisabled() async {
    // Empty title should disable saving
    await sut.onAction(.updateTitle(""))
    XCTAssertTrue(sut.viewState.isSavingDisabled)

    // Non-empty title should enable saving
    await sut.onAction(.updateTitle("Test Title"))
    XCTAssertFalse(sut.viewState.isSavingDisabled)

    // Saving in progress should disable saving
    await sut.onAction(.finishEditing(save: true))
    XCTAssertTrue(sut.viewState.isSavingDisabled)
  }

  // MARK: - Action Tests

  func testUpdateTitle() async {
    await sut.onAction(.startEditing)
    await sut.onAction(.updateTitle("Test Title"))
    XCTAssertEqual(sut.viewState.title, "Test Title")
    XCTAssertTrue(sut.viewState.isEditing)
  }

  func testUpdateContent() async {
    await sut.onAction(.updateContent("Test Content"))
    XCTAssertEqual(sut.viewState.content, "Test Content")
  }

  func testStartEditing() async {
    await sut.onAction(.startEditing)
    try? await Task.sleep(for: .seconds(0.1))
    XCTAssertTrue(sut.viewState.isEditing)
  }

  func testFinishEditingWithoutSave() async {
    // Setup initial editing state
    await sut.onAction(.startEditing)
    await sut.onAction(.updateTitle("Test Title"))
    await sut.onAction(.updateContent("Test Content"))
    XCTAssertTrue(sut.viewState.isEditing)

    // Cancel editing
    await sut.onAction(.finishEditing(save: false))
    XCTAssertFalse(sut.viewState.isEditing)
    XCTAssertTrue(sut.viewState.shouldDismiss)
  }

  func testFinishEditingWithSave() async {
    // Setup initial editing state
    await sut.onAction(.updateTitle("Test Title"))
    await sut.onAction(.updateContent("Test Content"))
    try? await Task.sleep(for: .seconds(0.1))
    XCTAssertFalse(sut.viewState.isEditing)

    await sut.onAction(.startEditing)
    try? await Task.sleep(for: .seconds(0.1))
    XCTAssertTrue(sut.viewState.isEditing)

    // Save entry
    await sut.onAction(.finishEditing(save: true))
    XCTAssertEqual(sut.viewState.savingStatus, .saving)

    // Wait for saving to complete
    try? await Task.sleep(for: .seconds(2.1))
    XCTAssertEqual(sut.viewState.savingStatus, .saved)
    XCTAssertFalse(sut.viewState.isEditing)
    XCTAssertTrue(sut.viewState.shouldDismiss)
  }

  func testFinishEditingWithEmptyTitle() async {
    await sut.onAction(.updateTitle(""))
    await sut.onAction(.finishEditing(save: true))
    XCTAssertEqual(sut.viewState.savingStatus, .saving)
    let state = await context.store.state
    XCTAssertEqual(state.entries.count, 0)
  }

  // MARK: - Store Integration Tests

  func testStoreUpdateOnNewEntry() async {
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
    }
    try? await Task.sleep(for: .seconds(0.1))
    await sut.onAction(.updateTitle("Test Title"))
    await sut.onAction(.updateContent("Test Content"))
    await sut.onAction(.finishEditing(save: true))

    // Wait for saving to complete
    try? await Task.sleep(for: .seconds(2.1))

    let state = await context.store.state
    XCTAssertEqual(state.entries.count, 1)
    let entry = state.entries[0]
    XCTAssertEqual(entry.title, "Test Title")
    XCTAssertEqual(entry.content, "Test Content")
  }

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
    await sut.onAction(.updateTitle("Updated Title"))
    await sut.onAction(.updateContent("Updated Content"))
    await sut.onAction(.finishEditing(save: true))

    // Wait for saving to complete
    try? await Task.sleep(for: .seconds(2.1))

    let state = await context.store.state
    XCTAssertEqual(state.entries.count, 1)
    let entry = state.entries[0]
    XCTAssertEqual(entry.title, "Updated Title")
    XCTAssertEqual(entry.content, "Updated Content")
  }

  func testStoreStateMapping() async {
    // Test adding new mode
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
    }
    // Wait for saving to complete
    try? await Task.sleep(for: .seconds(0.2))
    XCTAssertEqual(sut.viewState.entryTitle, "New Entry")
    XCTAssertFalse(sut.viewState.shouldDismiss)

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
    XCTAssertFalse(sut.viewState.shouldDismiss)

    // Test no selection mode
    await context.store.update { state in
      state.entrySelectionMode = .no
    }
    // Wait for saving to complete
    try? await Task.sleep(for: .seconds(0.2))
    XCTAssertEqual(sut.viewState.entryTitle, "")
    XCTAssertEqual(sut.viewState.title, "")
    XCTAssertEqual(sut.viewState.content, "")
    XCTAssertTrue(sut.viewState.shouldDismiss)
  }
} 
