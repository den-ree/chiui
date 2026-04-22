import Foundation
import Testing
@testable import DiaryApp
@testable import Chiui

@Suite("DiaryEntryLocationSelectionViewModel tests")
struct DiaryEntryLocationSelectionViewModelTests {
  @MainActor
  private func makeSUT() -> (sut: DiaryEntryLocationSelectionViewModel, context: DiaryContext) {
    let context = DiaryContext(initialState: DiaryStoreState())
    let sut = DiaryEntryLocationSelectionViewModel(context)
    return (sut, context)
  }

  @Test("Store update maps draft location")
  @MainActor
  func didStoreUpdateUsesDraftLocation() async {
    let (sut, context) = makeSUT()
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
      state.entryDraftLocation = "Kyoto"
      state.isSelectingEntryLocation = true
    }

    try? await Task.sleep(for: .seconds(0.1))

    #expect(sut.state.location == "Kyoto")
  }

  @Test("Store update maps selected entry location when draft is missing")
  @MainActor
  func didStoreUpdateUsesSelectedEntryLocationWhenNoDraft() async {
    let (sut, context) = makeSUT()
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

    #expect(sut.state.location == "Berlin")
  }

  @Test("locationChanged persists draft location")
  @MainActor
  func locationChangedUpdatesStoreDraft() async {
    let (sut, context) = makeSUT()
    await sut.sendAwaitingEffects(.locationChanged("Toronto"))
    try? await Task.sleep(for: .seconds(0.1))

    #expect(sut.state.location == "Toronto")
    let storeState = await context.store.state
    #expect(storeState.entryDraftLocation == "Toronto")
  }

  @Test("confirmSelection dismisses location selection")
  @MainActor
  func confirmSelectionDismissesLocationSelection() async {
    let (sut, context) = makeSUT()
    await context.store.update { state in
      state.isSelectingEntryLocation = true
    }

    await sut.sendAwaitingEffects(.confirmSelection)
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    #expect(storeState.isSelectingEntryLocation == false)
  }

  @Test("cancelSelection dismisses location selection")
  @MainActor
  func cancelSelectionDismissesLocationSelection() async {
    let (sut, context) = makeSUT()
    await context.store.update { state in
      state.isSelectingEntryLocation = true
    }

    await sut.sendAwaitingEffects(.cancelSelection)
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    #expect(storeState.isSelectingEntryLocation == false)
  }

  @Test("Reducer emits persistDraftLocation effect")
  @MainActor
  func reducerProducesPersistEffect() {
    var state = DiaryEntryLocationSelectionViewModel.State()
    let effect = DiaryEntryLocationSelectionViewModel.respond(to: .locationChanged("Oslo"), state: &state)
    #expect(state.location == "Oslo")
    #expect(effect == .persistDraftLocation("Oslo"))
  }
}
