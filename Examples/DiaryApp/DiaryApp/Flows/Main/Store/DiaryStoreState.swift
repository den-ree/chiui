import Foundation
import Chiui

struct DiaryStoreState: ContextualStoreState {
  var entries: [DiaryEntry] = []
  var entrySelectionMode: EntrySelectionMode = .no
  var entryDraftDate: Date?
  var entryDraftMood: DiaryEntryMood?
  var entryDraftLocation: String?
  var isSelectingEntryDate: Bool = false
  var isSelectingEntryMood: Bool = false
  var isSelectingEntryLocation: Bool = false
  var isSavingChanges: Bool = false
}

enum EntrySelectionMode: Equatable {
  case no
  case selecting(DiaryEntry)
  case addingNew
}

struct EntryInput: Equatable {
  let title: String
  let content: String

  func new(title: String) -> EntryInput {
    .init(title: title, content: content)
  }

  func new(content: String) -> EntryInput {
    .init(title: title, content: content)
  }
}

enum DiaryAction: Equatable {
  case addEntry(DiaryEntry)
  case removeEntry(UUID)
  case updateEntry(DiaryEntry)
}
