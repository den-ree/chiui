import Foundation
import Testing
@testable import DiaryApp
@testable import Chiui

@Suite("DiaryEntryMoodSelectionViewModel tests")
struct DiaryEntryMoodSelectionViewModelTests {
  @MainActor
  private func makeSUT() -> (sut: DiaryEntryMoodSelectionViewModel, context: DiaryContext) {
    let context = DiaryContext(initialState: DiaryStoreState())
    let sut = DiaryEntryMoodSelectionViewModel(context)
    return (sut, context)
  }

  @Test("Store update maps draft mood")
  @MainActor
  func didStoreUpdateUsesDraftMood() async {
    let (sut, context) = makeSUT()
    await context.store.update { state in
      state.entrySelectionMode = .addingNew
      state.entryDraftMood = .great
      state.isSelectingEntryMood = true
    }

    try? await Task.sleep(for: .seconds(0.1))

    #expect(sut.state.selectedMood == .great)
  }

  @Test("Store update maps selected entry mood when draft is missing")
  @MainActor
  func didStoreUpdateUsesSelectedEntryMoodWhenNoDraft() async {
    let (sut, context) = makeSUT()
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

    #expect(sut.state.selectedMood == .bad)
  }

  @Test("selectedMoodChanged persists draft mood")
  @MainActor
  func updateSelectedMoodUpdatesStoreDraft() async {
    let (sut, context) = makeSUT()
    await sut.sendAwaitingEffects(.selectedMoodChanged(.amazing))
    try? await Task.sleep(for: .seconds(0.1))

    #expect(sut.state.selectedMood == .amazing)
    let storeState = await context.store.state
    #expect(storeState.entryDraftMood == .amazing)
  }

  @Test("confirmSelection dismisses mood selection")
  @MainActor
  func confirmSelectionDismissesMoodSelection() async {
    let (sut, context) = makeSUT()
    await context.store.update { state in
      state.isSelectingEntryMood = true
    }

    await sut.sendAwaitingEffects(.confirmSelection)
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    #expect(storeState.isSelectingEntryMood == false)
  }

  @Test("cancelSelection dismisses mood selection")
  @MainActor
  func cancelSelectionDismissesMoodSelection() async {
    let (sut, context) = makeSUT()
    await context.store.update { state in
      state.isSelectingEntryMood = true
    }

    await sut.sendAwaitingEffects(.cancelSelection)
    try? await Task.sleep(for: .seconds(0.1))

    let storeState = await context.store.state
    #expect(storeState.isSelectingEntryMood == false)
  }

  @Test("Reducer emits persistDraftMood effect")
  @MainActor
  func reducerProducesPersistEffect() {
    var state = DiaryEntryMoodSelectionViewModel.State()
    let effect = DiaryEntryMoodSelectionViewModel.respond(to: .selectedMoodChanged(.great), state: &state)
    #expect(state.selectedMood == .great)
    #expect(effect == .persistDraftMood(.great))
  }
}
