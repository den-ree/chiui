import Foundation
import Testing
@testable import DiaryApp
@testable import Chiui

@Suite("DiaryEntryDateSelectionViewModel tests")
struct DiaryEntryDateSelectionViewModelTests {
  @MainActor
  private func makeSUT() -> (sut: DiaryEntryDateSelectionViewModel, context: DiaryContext) {
    let context = DiaryContext(initialState: DiaryStoreState())
    let sut = DiaryEntryDateSelectionViewModel(context)
    return (sut, context)
  }

  @Test("Store update maps draft date")
  @MainActor
  func didStoreUpdateUsesDraftDate() async {
    let (sut, context) = makeSUT()
    let draftDate = Date(timeIntervalSince1970: 1_750_000_000)

    await context.store.update { state in
      state.entrySelectionMode = .addingNew
      state.entryDraftDate = draftDate
      state.isSelectingEntryDate = true
    }

    try? await Task.sleep(for: .seconds(0.1))

    #expect(sut.state.selectedDate == draftDate)
  }

  @Test("selectedDateChanged persists draft date")
  @MainActor
  func updateSelectedDateUpdatesStoreDraft() async {
    let (sut, context) = makeSUT()
    let selectedDate = Date(timeIntervalSince1970: 1_760_000_000)

    await sut.sendAwaitingEffects(.selectedDateChanged(selectedDate))
    try? await Task.sleep(for: .seconds(0.1))

    #expect(sut.state.selectedDate == selectedDate)
    let storeState = await context.store.state
    #expect(storeState.entryDraftDate == selectedDate)
  }

  @Test("confirmSelection dismisses date selection")
  @MainActor
  func confirmSelectionDismissesDateSelection() async {
    let (sut, context) = makeSUT()
    await context.store.update { state in
      state.isSelectingEntryDate = true
    }

    await sut.sendAwaitingEffects(.confirmSelection)
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    #expect(storeState.isSelectingEntryDate == false)
  }

  @Test("cancelSelection dismisses date selection")
  @MainActor
  func cancelSelectionDismissesDateSelection() async {
    let (sut, context) = makeSUT()
    await context.store.update { state in
      state.isSelectingEntryDate = true
    }

    await sut.sendAwaitingEffects(.cancelSelection)
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    #expect(storeState.isSelectingEntryDate == false)
  }

  @Test("Reducer emits persistDraftDate effect")
  @MainActor
  func reducerProducesPersistEffect() {
    var state = DiaryEntryDateSelectionViewModel.State()
    let date = Date(timeIntervalSince1970: 1_760_000_000)
    let effect = DiaryEntryDateSelectionViewModel.respond(to: .selectedDateChanged(date), state: &state)
    #expect(state.selectedDate == date)
    #expect(effect == .persistDraftDate(date))
  }
}
