import Foundation
import Chiui

/// Represents the global state of the diary application
struct DiaryStoreState: ContextualStoreState {
  /// Collection of all diary entries
  var entries: [DiaryEntry] = []
  var entrySelectionMode: EntrySelectionMode = .no
  var entryDraftDate: Date? = nil
  var isSelectingEntryDate: Bool = false
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

/// Actions that can be performed on the diary store
enum DiaryAction: Equatable {
  /// Add a new diary entry
  case addEntry(DiaryEntry)
  /// Remove a diary entry by its ID
  case removeEntry(UUID)
  /// Update an existing diary entry
  case updateEntry(DiaryEntry)
}
