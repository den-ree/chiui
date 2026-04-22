import XCTest
@testable import DiaryApp
@testable import Chiui

final class DiaryEntryLocationSelectionViewModelTests: XCTestCase {
  var sut: DiaryEntryLocationSelectionViewModel!
  var context: DiaryContext!

  override func setUp() async throws {
    try await super.setUp()
    await MainActor.run {
      context = DiaryContext(initialState: DiaryStoreState())
      sut = DiaryEntryLocationSelectionViewModel(context)
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
  func testDidStoreUpdateUsesDraftLocation() async {
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
      state.entryDraftLocation = "Kyoto"
      state.isSelectingEntryLocation = true
    }

    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.state.location, "Kyoto")
  }

  @MainActor
  func testDidStoreUpdateUsesSelectedEntryLocationWhenNoDraft() async {
    let entry = DiaryEntry(
      id: UUID(),
      title: "Title",
      content: "Content",
      createdAt: .now,
      mood: .bad,
      location: "Berlin"
    )

    await context.store.update { state in
      state.entrySelectionMode = .selecting(entry)
      state.entryDraftLocation = nil
    }

    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.state.location, "Berlin")
  }

  @MainActor
  func testLocationChangedUpdatesStoreDraft() async {
    await sut.sendAwaitingEffects(.locationChanged("Toronto"))
    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.state.location, "Toronto")
    let storeState = await context.store.state
    XCTAssertEqual(storeState.entryDraftLocation, "Toronto")
  }

  @MainActor
  func testConfirmSelectionDismissesLocationSelection() async {
    await context.store.update { state in
      state.isSelectingEntryLocation = true
    }

    await sut.sendAwaitingEffects(.confirmSelection)
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    XCTAssertFalse(storeState.isSelectingEntryLocation)
  }

  @MainActor
  func testCancelSelectionDismissesLocationSelection() async {
    await context.store.update { state in
      state.isSelectingEntryLocation = true
    }

    await sut.sendAwaitingEffects(.cancelSelection)
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    XCTAssertFalse(storeState.isSelectingEntryLocation)
  }

  @MainActor
  func testReducerProducesPersistEffect() {
    var state = DiaryEntryLocationSelectionViewModel.State()
    let effect = DiaryEntryLocationSelectionViewModel.respond(to: .locationChanged("Oslo"), state: &state)
    XCTAssertEqual(state.location, "Oslo")
    XCTAssertEqual(effect, .persistDraftLocation("Oslo"))
  }
}
