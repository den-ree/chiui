import XCTest
@testable import DiaryApp
@testable import Chiui

final class DiaryEntryDateSelectionViewModelTests: XCTestCase {
  var sut: DiaryEntryDateSelectionViewModel!
  var context: DiaryContext!

  override func setUp() async throws {
    try await super.setUp()
    await MainActor.run {
      context = DiaryContext(initialState: DiaryStoreState())
      sut = DiaryEntryDateSelectionViewModel(context)
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
  func testDidStoreUpdateUsesDraftDate() async {
    let draftDate = Date(timeIntervalSince1970: 1_750_000_000)

    await context.store.update { state in
      state.entrySelectionMode = .addingNew
      state.entryDraftDate = draftDate
      state.isSelectingEntryDate = true
    }

    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.state.selectedDate, draftDate)
  }

  @MainActor
  func testUpdateSelectedDateUpdatesStoreDraft() async {
    let selectedDate = Date(timeIntervalSince1970: 1_760_000_000)

    await sut.sendAwaitingEffects(.selectedDateChanged(selectedDate))
    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.state.selectedDate, selectedDate)
    let storeState = await context.store.state
    XCTAssertEqual(storeState.entryDraftDate, selectedDate)
  }

  @MainActor
  func testConfirmSelectionDismissesDateSelection() async {
    await context.store.update { state in
      state.isSelectingEntryDate = true
    }

    await sut.sendAwaitingEffects(.confirmSelection)
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    XCTAssertFalse(storeState.isSelectingEntryDate)
  }

  @MainActor
  func testCancelSelectionDismissesDateSelection() async {
    await context.store.update { state in
      state.isSelectingEntryDate = true
    }

    await sut.sendAwaitingEffects(.cancelSelection)
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    XCTAssertFalse(storeState.isSelectingEntryDate)
  }

  @MainActor
  func testReducerProducesPersistEffect() {
    var state = DiaryEntryDateSelectionViewModel.State()
    let date = Date(timeIntervalSince1970: 1_760_000_000)
    let effect = DiaryEntryDateSelectionViewModel.respond(to: .selectedDateChanged(date), state: &state)
    XCTAssertEqual(state.selectedDate, date)
    XCTAssertEqual(effect, .persistDraftDate(date))
  }
}
