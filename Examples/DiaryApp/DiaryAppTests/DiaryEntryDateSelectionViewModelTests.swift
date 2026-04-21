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

    XCTAssertEqual(sut.viewState.selectedDate, draftDate)
  }

  @MainActor
  func testUpdateSelectedDateUpdatesStoreDraft() async {
    let selectedDate = Date(timeIntervalSince1970: 1_760_000_000)

    sut.updateSelectedDate(selectedDate)
    try? await Task.sleep(for: .seconds(0.1))

    XCTAssertEqual(sut.viewState.selectedDate, selectedDate)
    let storeState = await context.store.state
    XCTAssertEqual(storeState.entryDraftDate, selectedDate)
  }

  @MainActor
  func testConfirmSelectionDismissesDateSelection() async {
    await context.store.update { state in
      state.isSelectingEntryDate = true
    }

    sut.confirmSelection()
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    XCTAssertFalse(storeState.isSelectingEntryDate)
  }

  @MainActor
  func testCancelSelectionDismissesDateSelection() async {
    await context.store.update { state in
      state.isSelectingEntryDate = true
    }

    sut.cancelSelection()
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    XCTAssertFalse(storeState.isSelectingEntryDate)
  }
}
