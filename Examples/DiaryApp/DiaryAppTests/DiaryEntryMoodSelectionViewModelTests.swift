import XCTest
@testable import DiaryApp
@testable import Chiui

final class DiaryEntryMoodSelectionViewModelTests: XCTestCase {
  var sut: DiaryEntryMoodSelectionViewModel!
  var context: DiaryContext!

  override func setUp() async throws {
    try await super.setUp()
    await MainActor.run {
      context = DiaryContext(initialState: DiaryStoreState())
      sut = DiaryEntryMoodSelectionViewModel(context)
    }
  }

  override func tearDown() async throws {
    await MainActor.run {
      sut = nil
      context = nil
    }
    try await super.tearDown()
  }

  @MainActor
  func testDidStoreUpdateUsesDraftMood() async {
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
      state.entryDraftMood = .great
      state.isSelectingEntryMood = true
    }

    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.viewState.selectedMood, .great)
  }

  @MainActor
  func testDidStoreUpdateUsesSelectedEntryMoodWhenNoDraft() async {
    let entry = DiaryEntry(
      id: UUID(),
      title: "Title",
      content: "Content",
      createdAt: .now,
      mood: .bad
    )

    await context.store.update { state in
      state.entrySelectionMode = .selecting(entry)
      state.entryDraftMood = nil
    }

    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.viewState.selectedMood, .bad)
  }

  @MainActor
  func testUpdateSelectedMoodUpdatesStoreDraft() async {
    sut.updateSelectedMood(.amazing)
    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.viewState.selectedMood, .amazing)
    let storeState = await context.store.state
    XCTAssertEqual(storeState.entryDraftMood, .amazing)
  }

  @MainActor
  func testConfirmSelectionDismissesMoodSelection() async {
    await context.store.update { state in
      state.isSelectingEntryMood = true
    }

    sut.confirmSelection()
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    XCTAssertFalse(storeState.isSelectingEntryMood)
  }

  @MainActor
  func testCancelSelectionDismissesMoodSelection() async {
    await context.store.update { state in
      state.isSelectingEntryMood = true
    }

    sut.cancelSelection()
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    XCTAssertFalse(storeState.isSelectingEntryMood)
  }
}
